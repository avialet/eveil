import Foundation

/// Session enregistree (UserDefaults `EveilSession`, JSON) avec l'heure de demarrage du Mac.
public struct SavedSession: Codable, Equatable, Sendable {
    public var session: Session
    /// `kern.boottime` au moment de l'enregistrement.
    public var bootTime: Date
    /// Heure de sortie de l'app (Cmd-Q, mise a jour) ; nil tant qu'elle tourne (ou apres un plantage).
    public var quitAt: Date?

    public init(session: Session, bootTime: Date, quitAt: Date? = nil) {
        self.session = session
        self.bootTime = bootTime
        self.quitAt = quitAt
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> SavedSession? { try? JSONDecoder().decode(SavedSession.self, from: data) }
}

public enum ResumeDecision: Equatable, Sendable {
    case resume(Session)
    case discard
}

/// Au lancement : reprendre la session d'avant une relance (mise a jour, plantage) si le Mac n'a pas
/// redemarre, qu'elle n'est pas finie et, si l'app a quitte, qu'elle a ete relancee dans la minute
/// (une mise a jour se relance seule ; quitter a la main arrete la session) ; sinon l'abandonner.
public enum ResumePolicy {
    /// Ecart tolere sur l'heure de demarrage relue (arrondis de `timeval`).
    public static let bootTolerance: TimeInterval = 1
    /// Delai de relance apres une sortie (mise a jour : quelques secondes).
    public static let relaunchWindow: TimeInterval = 60

    public static func decide(_ saved: SavedSession?, bootTime: Date, now: Date) -> ResumeDecision {
        guard let saved else { return .discard }
        guard abs(saved.bootTime.timeIntervalSince(bootTime)) < bootTolerance else { return .discard }
        if let quitAt = saved.quitAt, now.timeIntervalSince(quitAt) > relaunchWindow { return .discard }
        if let end = saved.session.end, end <= now { return .discard }
        return .resume(saved.session)
    }
}
