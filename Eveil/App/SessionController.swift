import AppKit
import EveilCore
import Observation

/// Orchestre une session : assertion d'energie, fin, conditions (alimentation, app, telechargements),
/// enregistrement pour la reprise, et statut publie (pour Vialet a partir du kit 0.2.6).
@MainActor
@Observable
final class SessionController {
    static let shared = SessionController()

    struct StopNote: Equatable {
        let reason: StopReason
        let date: Date
    }

    private(set) var session: Session?
    private(set) var lastStop: StopNote?
    /// Un partiel a grossi recemment (session telechargement).
    private(set) var downloadActive = false

    var isActive: Bool { session != nil }

    @ObservationIgnored var calendar = Calendar.autoupdatingCurrent
    /// Horloge (fixe dans le mode capture).
    @ObservationIgnored var clock: () -> Date = { Date() }
    /// Statut a publier quand il change (texte de la phrase d'etat, actif ou non). Kit 0.2.6 :
    /// `AppActions.shared.setStatus(...)` et `setVisible(...)` ; d'ici la, rien.
    @ObservationIgnored var onStatusChange: ((HubStatus) -> Void)?

    @ObservationIgnored private var assertion: PowerAssertion?
    @ObservationIgnored private var activity: NSObjectProtocol?
    @ObservationIgnored private var tick: Timer?
    @ObservationIgnored private var endTimer: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var publishedStatus: HubStatus?
    /// Mode capture : etat affiche sans assertion ni minuterie.
    @ObservationIgnored private var previewOnly = false

    var now: Date { clock() }

    // MARK: Lancement

    /// Branche les sources de signaux et reprend la session d'avant une relance si elle vaut encore.
    func launch() {
        PowerSource.shared.onChange = { [weak self] in self?.evaluate() }
        PowerSource.shared.start()
        AppWatcher.shared.onChange = { [weak self] in self?.evaluate() }
        AppWatcher.shared.start()
        DownloadsWatcher.shared.onTick = { [weak self] in self?.evaluate() }
        let wake = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SessionController.shared.evaluate() }
        }
        observers = [wake]
        restore()
        publishStatus()
    }

    private func restore() {
        let defaults = UserDefaults.standard
        let saved = defaults.data(forKey: Prefs.session).flatMap(SavedSession.decode)
        guard let boot = BootTime.current(),
              case .resume(let session) = ResumePolicy.decide(saved, bootTime: boot, now: now) else {
            defaults.removeObject(forKey: Prefs.session)
            return
        }
        begin(session)
    }

    // MARK: Commandes

    func start(_ choice: SessionChoice) {
        let keep = UserDefaults.standard.bool(forKey: Prefs.keepDisplayOn(choice.family))
        switch choice {
        case .minutes(let minutes): UserDefaults.standard.set(minutes, forKey: Prefs.lastTimed)
        case .indefinite: UserDefaults.standard.set(0, forKey: Prefs.lastTimed)
        case .download: UserDefaults.standard.set(true, forKey: Prefs.downloadsUsed)
        default: break
        }
        let power = PowerSource.shared
        power.refresh()
        begin(Session.start(choice, keepDisplayOn: keep, now: now, calendar: calendar,
                            lowPowerMode: power.lowPowerMode, batteryPercent: power.onACPower ? nil : power.batteryPercent))
    }

    /// Bascule du raccourci : arreter, ou reprendre la derniere duree.
    func toggle() {
        if isActive { stop(.user); return }
        let minutes = UserDefaults.standard.integer(forKey: Prefs.lastTimed)
        start(minutes > 0 ? .minutes(minutes) : .indefinite)
    }

    func stop(_ reason: StopReason = .user) {
        guard session != nil else { return }
        session = nil
        lastStop = StopNote(reason: reason, date: now)
        downloadActive = false
        teardown()
        UserDefaults.standard.removeObject(forKey: Prefs.session)
        publishStatus()
    }

    /// << +1 h >> : repousse la fin d'une duree ou d'une heure.
    func extend(by seconds: TimeInterval = 3600) {
        guard var session, session.canExtend else { return }
        session.extend(by: seconds)
        self.session = session
        apply()
    }

    /// << Garder l'ecran allume >> pendant une session, memorise pour sa famille.
    func setKeepDisplayOn(_ on: Bool) {
        guard var session, session.keepDisplayOn != on else { return }
        session.keepDisplayOn = on
        UserDefaults.standard.set(on, forKey: Prefs.keepDisplayOn(session.kind.family))
        self.session = session
        apply()
    }

    // MARK: Evaluation

    func evaluate() {
        guard !previewOnly, var session else { return }
        let date = now
        let power = PowerSource.shared
        power.refresh()
        var appRunning = false
        if case .app(let bundleID, _) = session.kind {
            appRunning = AppWatcher.shared.isRunning(bundleID)
            if appRunning, !session.appSeen {
                session.appSeen = true
                self.session = session
                save()
                publishStatus()
            }
        }
        if session.kind == .download {
            let active = DownloadsWatcher.shared.isActive(at: date)
            if active != downloadActive { downloadActive = active }
        }
        let signals = Signals(now: date, onACPower: power.onACPower, batteryPercent: power.batteryPercent,
                              lowPowerMode: power.lowPowerMode, appRunning: appRunning,
                              downloadsFinished: session.kind == .download && DownloadsWatcher.shared.isFinished(at: date))
        if case .stop(let reason) = Evaluator.evaluate(session, signals, rules: Prefs.batteryRules) {
            stop(reason)
        }
    }

    // MARK: Mecanique

    private func begin(_ session: Session) {
        self.session = session
        lastStop = nil
        downloadActive = false
        if session.kind == .download {
            DownloadsWatcher.shared.start(since: session.start)
        } else {
            DownloadsWatcher.shared.stop()
        }
        if activity == nil {
            // Pas d'App Nap pendant une session : la fin et les releves restent a l'heure.
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                             reason: "Session \u{00C9}veil")
        }
        if tick == nil {
            let timer = Timer(timeInterval: 15, repeats: true) { _ in
                MainActor.assumeIsolated { SessionController.shared.evaluate() }
            }
            timer.tolerance = 3
            RunLoop.main.add(timer, forMode: .common)
            tick = timer
        }
        apply()
        evaluate()
    }

    /// Assertion, minuterie de fin, enregistrement et statut pour la session courante.
    private func apply() {
        guard let session else { return }
        let reason = StatusText.headline(session, now: now, calendar: calendar)
        // Delai de securite : l'OS relache l'assertion une minute apres la fin, meme si l'app est figee.
        let timeout = session.end.map { $0.timeIntervalSince(now) + 60 }
        assertion = nil
        assertion = PowerAssertion(keepDisplayOn: session.keepDisplayOn, reason: reason, timeout: timeout)
        // Assertion refusee : ne jamais afficher une session qui ne tient pas le Mac eveille.
        guard assertion != nil else {
            stop(.refused)
            return
        }
        endTimer?.invalidate()
        endTimer = nil
        if let end = session.end {
            let timer = Timer(fire: end, interval: 0, repeats: false) { _ in
                MainActor.assumeIsolated { SessionController.shared.evaluate() }
            }
            RunLoop.main.add(timer, forMode: .common)
            endTimer = timer
        }
        save()
        publishStatus()
    }

    private func teardown() {
        assertion = nil
        endTimer?.invalidate()
        endTimer = nil
        tick?.invalidate()
        tick = nil
        DownloadsWatcher.shared.stop()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        activity = nil
    }

    private func save(quitAt: Date? = nil) {
        guard let session, let boot = BootTime.current(),
              let data = try? SavedSession(session: session, bootTime: boot, quitAt: quitAt).encoded() else { return }
        UserDefaults.standard.set(data, forKey: Prefs.session)
    }

    private func publishStatus() {
        let status = StatusText.hub(session, now: now, calendar: calendar)
        guard status != publishedStatus else { return }
        publishedStatus = status
        onStatusChange?(status)
    }

    // MARK: Fin de l'app

    /// A la sortie : l'assertion tombe (l'OS la relacherait de toute facon). La session reste
    /// enregistree avec l'heure de sortie : reprise si l'app est relancee dans la minute (mise a jour).
    func terminate() {
        guard !previewOnly else { return }
        save(quitAt: now)
        teardown()
    }

    #if DEBUG
    /// Mode capture : un etat fictif, sans assertion ni minuterie ni enregistrement.
    func preview(session: Session?, lastStop: StopNote? = nil, downloadActive: Bool = false, clock: Date) {
        previewOnly = true
        self.clock = { clock }
        self.session = session
        self.lastStop = lastStop
        self.downloadActive = downloadActive
    }
    #endif
}
