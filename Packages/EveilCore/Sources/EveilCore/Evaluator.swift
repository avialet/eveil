import Foundation

/// Etat du Mac au moment d'evaluer une session.
public struct Signals: Equatable, Sendable {
    public var now: Date
    public var onACPower: Bool
    /// Charge de la batterie interne, nil sans batterie (Mac de bureau).
    public var batteryPercent: Int?
    public var lowPowerMode: Bool
    /// App de la session << tant qu'une app tourne >> ouverte.
    public var appRunning: Bool
    /// Plus aucun fichier partiel n'a grossi depuis la grace (`PartialDownloads.isFinished`).
    public var downloadsFinished: Bool

    public init(now: Date, onACPower: Bool = true, batteryPercent: Int? = nil, lowPowerMode: Bool = false,
                appRunning: Bool = false, downloadsFinished: Bool = false) {
        self.now = now
        self.onACPower = onACPower
        self.batteryPercent = batteryPercent
        self.lowPowerMode = lowPowerMode
        self.appRunning = appRunning
        self.downloadsFinished = downloadsFinished
    }
}

/// Reglages << Batterie >> : arreter sous un seuil (sur batterie seulement) et en mode Economie d'energie.
public struct BatteryRules: Codable, Equatable, Sendable {
    public var stopBelow: Int?
    public var stopInLowPowerMode: Bool

    public static let thresholds = [10, 20, 30]
    public static let standard = BatteryRules(stopBelow: 20, stopInLowPowerMode: true)

    public init(stopBelow: Int?, stopInLowPowerMode: Bool) {
        self.stopBelow = stopBelow
        self.stopInLowPowerMode = stopInLowPowerMode
    }
}

/// Pourquoi une session s'arrete.
public enum StopReason: Codable, Equatable, Sendable {
    case user
    case ended
    case batteryLow(Int)
    case lowPowerMode
    case unplugged
    case appQuit(String)
    case downloadsDone
    /// macOS a refuse l'assertion d'energie : la session n'a jamais tenu le Mac eveille.
    case refused
}

public enum Verdict: Equatable, Sendable {
    case keep
    case stop(StopReason)
}

/// Decide si une session continue. Ordre : fin atteinte, debranchement (session secteur), batterie,
/// Economie d'energie, app quittee, telechargements finis. Batterie et Economie d'energie ne jouent que
/// s'ils surviennent pendant la session : deja la au debut, la session a ete demandee en connaissance de cause.
public enum Evaluator {
    public static func evaluate(_ session: Session, _ signals: Signals, rules: BatteryRules) -> Verdict {
        if let end = session.end, signals.now >= end { return .stop(.ended) }
        if session.kind == .power, !signals.onACPower { return .stop(.unplugged) }
        if !signals.onACPower, let threshold = rules.stopBelow, let percent = signals.batteryPercent,
           percent < threshold, (session.batteryAtStart ?? 100) >= threshold {
            return .stop(.batteryLow(percent))
        }
        if rules.stopInLowPowerMode, signals.lowPowerMode, !session.startedInLowPower { return .stop(.lowPowerMode) }
        switch session.kind {
        case .app(_, let name):
            if !signals.appRunning, session.appSeen { return .stop(.appQuit(name)) }
        case .download:
            if signals.downloadsFinished { return .stop(.downloadsDone) }
        default:
            break
        }
        return .keep
    }
}
