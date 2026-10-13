import Foundation

/// Heure de fin d'une session : toujours une `Date` absolue (le temps passe en veille compte),
/// jamais une minuterie seule.
public enum EndClock {
    public static func end(minutes: Int, from start: Date) -> Date {
        start.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    /// Prochaine occurrence de `hour:minute` strictement apres `now` (<< jusqu'a 9 h >> demande a 22 h :
    /// demain). Heure sautee au printemps : premiere heure valide suivante ; heure doublee a l'automne :
    /// la premiere.
    public static func nextOccurrence(hour: Int, minute: Int, after now: Date, calendar: Calendar) -> Date {
        let components = DateComponents(hour: hour, minute: minute, second: 0)
        return calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTime,
                                 repeatedTimePolicy: .first, direction: .forward)
            ?? now.addingTimeInterval(24 * 3600)
    }

    /// Avancement de 0 a 1 (barre de progression) ; une session sans duree est finie.
    public static func progress(start: Date, end: Date, now: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }
}
