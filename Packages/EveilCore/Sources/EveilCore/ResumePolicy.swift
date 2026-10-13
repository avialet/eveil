import Foundation

/// Session enregistree (UserDefaults `EveilSession`, JSON) avec l'heure de demarrage du Mac.
public struct SavedSession: Codable, Equatable, Sendable {
    public var session: Session
    /// `kern.boottime` au moment de l'enregistrement.
    public var bootTime: Date
    /// Heure de sortie de l'app (Cmd-Q, mise a jour) ; nil tant qu'elle tourne (ou apres un plantage).
    public var quitAt: Date?
    /// Derniere trace de l'app vivante (a chaque enregistrement et evaluation, toutes les 15 s) : apres un
    /// plantage, sans heure de sortie, elle en tient lieu.
    public var lastSeen: Date?

    public init(session: Session, bootTime: Date, quitAt: Date? = nil, lastSeen: Date? = nil) {
        self.session = session
        self.bootTime = bootTime
        self.quitAt = quitAt
        self.lastSeen = lastSeen
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public static func decode(_ data: Data) -> SavedSession? { try? JSONDecoder().decode(SavedSession.self, from: data) }
}

public enum ResumeDecision: Equatable, Sendable {
    case resume(Session)
    case discard
}

/// Au lancement : reprendre la session d'avant une relance (mise a jour, plantage) si le Mac n'a pas
/// redemarre, qu'elle n'est pas finie et que l'app a ete relancee dans la minute suivant sa sortie
/// (une mise a jour se relance seule ; quitter a la main arrete la session) ou, apres un plantage, sa
/// derniere trace (pas de session fantome reprise longtemps apres) ; sinon l'abandonner.
public enum ResumePolicy {
    /// Ecart tolere sur l'heure de demarrage relue (arrondis de `timeval`).
    public static let bootTolerance: TimeInterval = 1
    /// Delai de relance apres une sortie (mise a jour : quelques secondes).
    public static let relaunchWindow: TimeInterval = 60

    public static func decide(_ saved: SavedSession?, bootTime: Date, now: Date) -> ResumeDecision {
        guard let saved else { return .discard }
        guard abs(saved.bootTime.timeIntervalSince(bootTime)) < bootTolerance else { return .discard }
        if let gone = saved.quitAt ?? saved.lastSeen, now.timeIntervalSince(gone) > relaunchWindow { return .discard }
        if let end = saved.session.end, end <= now { return .discard }
        return .resume(saved.session)
    }
}
