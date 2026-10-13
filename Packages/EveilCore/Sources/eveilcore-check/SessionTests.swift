import Foundation
import EveilCore

let sessionTests: (String, [Test]) = ("Session", [
    Test("durationChoiceSetsEnd") {
        let s = Session.start(.minutes(60), keepDisplayOn: true, now: at(2026, 10, 14, 14, 40), calendar: paris)
        expectEqual(s.kind, .duration(minutes: 60))
        expectEqual(s.end, at(2026, 10, 14, 15, 40))
        expectEqual(s.start, at(2026, 10, 14, 14, 40))
        expect(s.keepDisplayOn)
        expect(s.canExtend)
    },
    Test("untilChoiceUsesNextOccurrence") {
        let s = Session.start(.until(hour: 9, minute: 0), keepDisplayOn: true, now: at(2026, 10, 14, 22, 0), calendar: paris)
        expectEqual(s.kind, .until)
        expectEqual(s.end, at(2026, 10, 15, 9, 0))
    },
    Test("openEndedChoicesHaveNoEnd") {
        let now = at(2026, 10, 14, 10, 0)
        for choice: SessionChoice in [.indefinite, .download, .power, .app(bundleID: "com.apple.iWork.Keynote", name: "Keynote")] {
            let s = Session.start(choice, keepDisplayOn: false, now: now, calendar: paris)
            expect(s.end == nil, "\(choice)")
            expect(!s.canExtend, "\(choice)")
        }
    },
    Test("extendAddsOneHourToEnd") {
        var s = Session.start(.minutes(15), keepDisplayOn: true, now: at(2026, 10, 14, 15, 0), calendar: paris)
        s.extend(by: 3600)
        expectEqual(s.end, at(2026, 10, 14, 16, 15))
        var open = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 15, 0), calendar: paris)
        open.extend(by: 3600)
        expect(open.end == nil)
    },
    Test("families") {
        expectEqual(SessionChoice.minutes(15).family, .timed)
        expectEqual(SessionChoice.until(hour: 1, minute: 0).family, .timed)
        expectEqual(SessionChoice.indefinite.family, .timed)
        expectEqual(SessionChoice.download.family, .condition)
        expectEqual(SessionChoice.power.family, .condition)
        expectEqual(SessionChoice.app(bundleID: "a", name: "A").family, .condition)
        // Ecran allume par defaut pour les durees, libre pour les conditions.
        expect(SessionFamily.timed.defaultKeepsDisplayOn)
        expect(!SessionFamily.condition.defaultKeepsDisplayOn)
    },
    Test("codableRoundTrip") {
        var s = Session.start(.app(bundleID: "com.apple.iWork.Keynote", name: "Keynote"), keepDisplayOn: false,
                              now: at(2026, 10, 14, 10, 0), calendar: paris)
        s.appSeen = true
        let data = try JSONEncoder().encode(s)
        expectEqual(try JSONDecoder().decode(Session.self, from: data), s)
    },
])
