import Foundation

/// Session enregistree (UserDefaults `EveilSession`, JSON) avec l'heure de demarrage du Mac.
public struct SavedSession: Codable, Equatable, Sendable {
    public var session: Session
    /// `kern.boottime` au moment de l'enregistrement.
    public var bootTime: Date

    public init(session: Session, bootTime: Date) {
        self.session = session
        self.bootTime = bootTime
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> SavedSession? { try? JSONDecoder().decode(SavedSession.self, from: data) }
}

public enum ResumeDecision: Equatable, Sendable {
    case resume(Session)
    case discard
}

/// Au lancement : reprendre la session d'avant une relance (mise a jour, plantage) si le Mac n'a pas
/// redemarre et qu'elle n'est pas finie ; sinon l'abandonner.
public enum ResumePolicy {
    /// Ecart toleré sur l'heure de demarrage relue (arrondis de `timeval`).
    public static let bootTolerance: TimeInterval = 1

    public static func decide(_ saved: SavedSession?, bootTime: Date, now: Date) -> ResumeDecision {
        guard let saved else { return .discard }
        guard abs(saved.bootTime.timeIntervalSince(bootTime)) < bootTolerance else { return .discard }
        if let end = saved.session.end, end <= now { return .discard }
        return .resume(saved.session)
    }
}
