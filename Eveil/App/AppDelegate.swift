import AppKit
import EveilCore
import VialetKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Mode capture (DEBUG) : ni assertion, ni icone, ni raccourci, ni reseau.
    static var isSnapshot: Bool {
        #if DEBUG
        SnapshotRequest.parse(prefix: Brand.name, arguments: CommandLine.arguments) != nil
        #else
        false
        #endif
    }

    /// Une URL `eveil://` a lance ou reveille l'app : pas de fenetre d'office.
    private var receivedURL = false

    /// Actions servies par URL sans etre proposees dans Vialet.
    private let hiddenActions: [String: @MainActor () -> Void] = [
        "15min": { SessionController.shared.start(.minutes(15)) },
        "2h": { SessionController.shared.start(.minutes(120)) },
        "telechargement": { SessionController.shared.start(.download) },
    ]

    /// Avant toute URL recue au lancement (`open -g eveil://1h`) : actions et session prets.
    func applicationWillFinishLaunching(_ notification: Notification) {
        Prefs.register()
        MainWindowController.shared.install()
        guard !Self.isSnapshot else { return }
        let actions = AppActions.shared
        actions.register(AppAction("1h", title: "1\u{00A0}h", symbol: "sun.max", visible: .idle)) {
            SessionController.shared.start(.minutes(60))
        }
        actions.register(AppAction("sans-fin", title: "Sans fin", symbol: "infinity", visible: .idle)) {
            SessionController.shared.start(.indefinite)
        }
        actions.register(AppAction("arreter", title: "Arr\u{00EA}ter", symbol: "stop.circle", visible: .active)) {
            SessionController.shared.stop()
        }
        // Etat de la session dans Vialet ou le menu rassembleur (a chaque changement, pas de decompte).
        SessionController.shared.onStatusChange = { status in
            AppActions.shared.publish(status: status.text.isEmpty ? nil : status.text, active: status.active)
        }
        SessionController.shared.launch()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceChoice.current(defaultsKey: Brand.key("Appearance")).apply(defaultsKey: Brand.key("Appearance"))
        #if DEBUG
        if runSnapshotIfRequested() { return }
        #endif
        _ = DockPresence.shared
        HubPresence.start(menuBar: MenuBarPresence.shared, actions: AppActions.shared, updater: Updater.shared)
        if UserDefaults.standard.bool(forKey: Prefs.hotKeyEnabled) { EveilHotKey.apply(true) }
        // Lancement ordinaire (Finder, Spotlight, Dock) : la fenetre. Pas pour une URL ni a la connexion.
        let showWindow = Self.isOrdinaryLaunch(NSAppleEventManager.shared().currentAppleEvent)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            MainActor.assumeIsolated {
                if showWindow, !self.receivedURL { MainWindowController.shared.show() }
            }
        }
        // Laisse l'app s'afficher avant le moindre appel reseau.
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            MainActor.assumeIsolated { Updater.shared.checkAutomatically() }
        }
    }

    /// Evenement d'ouverture ordinaire : << oapp >> qui n'est pas une ouverture a la connexion.
    private static func isOrdinaryLaunch(_ event: NSAppleEventDescriptor?) -> Bool {
        guard let event else { return true }
        guard event.eventClass == AEEventClass(kCoreEventClass), event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        let property = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
        return property != OSType(keyAELaunchedAsLogInItem)
    }

    /// Liens `eveil://` : actions de Vialet (`1h`, `sans-fin`, `arreter`), actions cachees (`15min`, `2h`,
    /// `telechargement`), `open` et `update`.
    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURL = true
        guard !Self.isSnapshot else { return }
        for url in urls {
            if case .action(let id)? = AppURLCommand.parse(url, scheme: AppActions.shared.scheme),
               let perform = hiddenActions[id] {
                perform()
            } else {
                AppActions.shared.handle(url)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        SessionController.shared.terminate()
        // Le menu rassembleur ne doit pas montrer une session d'une app arretee.
        AppActions.shared.publish(status: nil, active: false)
    }

    /// Fermer la fenetre ne quitte pas : la session continue.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { MainWindowController.shared.show() }
        return true
    }
}
