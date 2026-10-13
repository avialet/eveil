import Foundation

/// Famille d'une session : l'interrupteur << Garder l'ecran allume >> est memorise par famille.
public enum SessionFamily: String, Codable, Sendable, CaseIterable {
    /// Durees, heure de fin, sans fin : on est devant l'ecran, il reste allume par defaut.
    case timed
    /// Conditions (telechargement, app, secteur) : le Mac travaille seul, l'ecran peut s'eteindre.
    case condition

    public var defaultKeepsDisplayOn: Bool { self == .timed }
}

/// Ce que l'utilisateur demande.
public enum SessionChoice: Codable, Equatable, Sendable {
    case minutes(Int)
    case until(hour: Int, minute: Int)
    case indefinite
    case download
    case app(bundleID: String, name: String)
    case power

    public var family: SessionFamily {
        switch self {
        case .minutes, .until, .indefinite: .timed
        case .download, .app, .power: .condition
        }
    }
}

/// Nature d'une session en cours.
public enum SessionKind: Codable, Equatable, Sendable {
    case duration(minutes: Int)
    case until
    case indefinite
    case download
    case app(bundleID: String, name: String)
    case power

    public var family: SessionFamily {
        switch self {
        case .duration, .until, .indefinite: .timed
        case .download, .app, .power: .condition
        }
    }
}

/// Session en cours : ce qui la tient, l'ecran, le debut et, pour une duree ou une heure, la fin absolue.
public struct Session: Codable, Equatable, Sendable {
    public var kind: SessionKind
    public var keepDisplayOn: Bool
    public var start: Date
    /// Fin absolue (duree, heure) ; nil pour sans fin et les conditions.
    public var end: Date?
    /// Session << tant qu'une app tourne >> : l'app a ete vue ouverte (avant, on l'attend).
    public var appSeen: Bool

    public init(kind: SessionKind, keepDisplayOn: Bool, start: Date, end: Date? = nil, appSeen: Bool = false) {
        self.kind = kind
        self.keepDisplayOn = keepDisplayOn
        self.start = start
        self.end = end
        self.appSeen = appSeen
    }

    public static func start(_ choice: SessionChoice, keepDisplayOn: Bool, now: Date, calendar: Calendar) -> Session {
        switch choice {
        case .minutes(let minutes):
            Session(kind: .duration(minutes: minutes), keepDisplayOn: keepDisplayOn, start: now,
                    end: EndClock.end(minutes: minutes, from: now))
        case .until(let hour, let minute):
            Session(kind: .until, keepDisplayOn: keepDisplayOn, start: now,
                    end: EndClock.nextOccurrence(hour: hour, minute: minute, after: now, calendar: calendar))
        case .indefinite:
            Session(kind: .indefinite, keepDisplayOn: keepDisplayOn, start: now)
        case .download:
            Session(kind: .download, keepDisplayOn: keepDisplayOn, start: now)
        case .app(let bundleID, let name):
            Session(kind: .app(bundleID: bundleID, name: name), keepDisplayOn: keepDisplayOn, start: now)
        case .power:
            Session(kind: .power, keepDisplayOn: keepDisplayOn, start: now)
        }
    }

    /// Une fin a repousser (<< +1 h >>) : seulement les durees et les heures.
    public var canExtend: Bool { end != nil }

    public mutating func extend(by seconds: TimeInterval) {
        guard let end else { return }
        self.end = end.addingTimeInterval(seconds)
    }
}
