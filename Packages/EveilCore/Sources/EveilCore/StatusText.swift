import Foundation

/// Etat publie pour Vialet (kit 0.2.6 : champ `status` de la fiche) : 60 caracteres au plus.
public struct HubStatus: Equatable, Sendable {
    public static let maxLength = 60
    public var text: String
    public var active: Bool

    public init(text: String, active: Bool) {
        self.text = text.count > Self.maxLength ? String(text.prefix(Self.maxLength - 1)) + "\u{2026}" : text
        self.active = active
    }
}

/// Textes d'etat en francais, espaces insecables autour des unites et avant les deux-points.
public enum StatusText {
    static let nbsp = "\u{00A0}"
    static let awake = "\u{00C9}veill\u{00E9}"

    public static let idle = "Le Mac suit ses r\u{00E9}glages de veille"

    /// << 15 h 40 >>, << 9 h >>, << 9 h 05 >>.
    public static func time(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let hour = c.hour ?? 0, minute = c.minute ?? 0
        return minute == 0 ? "\(hour)\(nbsp)h" : "\(hour)\(nbsp)h\(nbsp)" + String(format: "%02d", minute)
    }

    /// Heure de fin avec son jour : << 15 h 40 >>, << demain 9 h >>, << vendredi 15 h 40 >>.
    public static func endTime(_ end: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        switch days {
        case ...0: return time(end, calendar: calendar)
        case 1: return "demain " + time(end, calendar: calendar)
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "EEEE"
            return formatter.string(from: end) + " " + time(end, calendar: calendar)
        }
    }

    public static func headline(_ session: Session, now: Date, calendar: Calendar) -> String {
        if let end = session.end {
            return "\(awake) jusqu\u{2019}\u{00E0} " + endTime(end, now: now, calendar: calendar)
        }
        switch session.kind {
        case .download: return "\(awake) tant qu\u{2019}un t\u{00E9}l\u{00E9}chargement avance"
        case .power: return "\(awake) tant que le Mac est sur secteur"
        case .app(_, let name):
            return session.appSeen ? "\(awake) tant que \(name) tourne" : "\(awake) en attendant \(name)"
        case .indefinite, .duration, .until: return "\(awake) jusqu\u{2019}\u{00E0} nouvel ordre"
        }
    }

    public static func display(_ on: Bool) -> String {
        on ? "\u{00C9}cran allum\u{00E9}" : "\u{00C9}cran libre de s\u{2019}\u{00E9}teindre"
    }

    /// Temps restant, arrondi a la minute superieure : << encore 1 h 12 >>, << encore 6 min >>.
    public static func remaining(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "moins d\u{2019}une minute" }
        let minutes = Int((seconds / 60).rounded(.up))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "encore \(m)\(nbsp)min" }
        return m == 0 ? "encore \(h)\(nbsp)h" : "encore \(h)\(nbsp)h\(nbsp)" + String(format: "%02d", m)
    }

    /// Fin d'une session : << Termine a 15 h 40 >>, << Arrete a 15 h 40 : batterie a 18 % >>.
    public static func stopped(_ reason: StopReason, at date: Date, calendar: Calendar) -> String {
        let when = "\u{00E0} " + time(date, calendar: calendar)
        let stopped = "Arr\u{00EA}t\u{00E9} \(when)"
        switch reason {
        case .ended: return "Termin\u{00E9} \(when)"
        case .user: return stopped
        case .batteryLow(let percent): return "\(stopped)\(nbsp): batterie \u{00E0} \(percent)\(nbsp)%"
        case .lowPowerMode: return "\(stopped)\(nbsp): mode \u{00C9}conomie d\u{2019}\u{00E9}nergie"
        case .unplugged: return "\(stopped)\(nbsp): chargeur d\u{00E9}branch\u{00E9}"
        case .appQuit(let name): return "\(stopped)\(nbsp): \(name) a \u{00E9}t\u{00E9} quitt\u{00E9}"
        case .downloadsDone: return "\(stopped)\(nbsp): plus de t\u{00E9}l\u{00E9}chargement en cours"
        }
    }

    /// Statut pour le menu de Vialet : la phrase d'etat pendant une session, rien au repos
    /// (Vialet garde alors l'accroche).
    public static func hub(_ session: Session?, now: Date, calendar: Calendar) -> HubStatus {
        guard let session else { return HubStatus(text: "", active: false) }
        return HubStatus(text: headline(session, now: now, calendar: calendar), active: true)
    }
}
