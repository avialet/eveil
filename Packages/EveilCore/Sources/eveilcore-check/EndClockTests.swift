import Foundation
import EveilCore

let endClockTests: (String, [Test]) = ("EndClock", [
    Test("durationAddsAbsoluteTime") {
        expectEqual(EndClock.end(minutes: 60, from: at(2026, 10, 14, 14, 40)), at(2026, 10, 14, 15, 40))
        expectEqual(EndClock.end(minutes: 15, from: at(2026, 10, 14, 23, 50)), at(2026, 10, 15, 0, 5))
    },
    Test("durationAcrossSpringForwardIsRealTime") {
        // 29 mars 2026 : 2 h -> 3 h a Paris. Une heure apres 1 h 30 = 3 h 30 a l'horloge.
        expectEqual(EndClock.end(minutes: 60, from: at(2026, 3, 29, 1, 30)), at(2026, 3, 29, 3, 30))
    },
    Test("untilLaterToday") {
        expectEqual(EndClock.nextOccurrence(hour: 18, minute: 0, after: at(2026, 10, 14, 15, 0), calendar: paris),
                    at(2026, 10, 14, 18, 0))
    },
    Test("untilEarlierHourIsTomorrow") {
        // << jusqu'a 9 h >> demande a 22 h : demain matin.
        expectEqual(EndClock.nextOccurrence(hour: 9, minute: 0, after: at(2026, 10, 14, 22, 0), calendar: paris),
                    at(2026, 10, 15, 9, 0))
    },
    Test("untilSameMinuteIsTomorrow") {
        expectEqual(EndClock.nextOccurrence(hour: 15, minute: 0, after: at(2026, 10, 14, 15, 0, 20), calendar: paris),
                    at(2026, 10, 15, 15, 0))
    },
    Test("untilMissingHourOnSpringForward") {
        // 2 h 30 n'existe pas le 29 mars 2026 : premiere heure valide suivante, 3 h.
        let end = EndClock.nextOccurrence(hour: 2, minute: 30, after: at(2026, 3, 28, 22, 0), calendar: paris)
        expectEqual(end, at(2026, 3, 29, 3, 0))
    },
    Test("untilRepeatedHourOnFallBackIsFirst") {
        // 25 octobre 2026 : 3 h -> 2 h. 2 h 30 depuis 1 h : la premiere, 1 h 30 plus tard.
        let end = EndClock.nextOccurrence(hour: 2, minute: 30, after: at(2026, 10, 25, 1, 0), calendar: paris)
        expectEqual(end.timeIntervalSince(at(2026, 10, 25, 1, 0)), 90 * 60)
    },
    Test("progress") {
        let start = at(2026, 10, 14, 15, 0), end = at(2026, 10, 14, 16, 0)
        expectEqual(EndClock.progress(start: start, end: end, now: at(2026, 10, 14, 15, 15)), 0.25)
        expectEqual(EndClock.progress(start: start, end: end, now: at(2026, 10, 14, 14, 0)), 0)
        expectEqual(EndClock.progress(start: start, end: end, now: at(2026, 10, 14, 17, 0)), 1)
        expectEqual(EndClock.progress(start: start, end: start, now: start), 1)
    },
])
