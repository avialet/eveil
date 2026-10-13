import Foundation
import EveilCore

private let boot = at(2026, 10, 14, 8, 0)
private let now = at(2026, 10, 14, 15, 0)

let resumePolicyTests: (String, [Test]) = ("ResumePolicy", [
    Test("nothingSaved") {
        expectEqual(ResumePolicy.decide(nil, bootTime: boot, now: now), .discard)
    },
    Test("resumesValidSessionAfterRelaunch") {
        let s = Session.start(.minutes(60), keepDisplayOn: true, now: at(2026, 10, 14, 14, 40), calendar: paris)
        expectEqual(ResumePolicy.decide(SavedSession(session: s, bootTime: boot), bootTime: boot, now: now), .resume(s))
        // Horodatage du demarrage relu a la seconde pres.
        expectEqual(ResumePolicy.decide(SavedSession(session: s, bootTime: boot.addingTimeInterval(0.6)),
                                        bootTime: boot, now: now), .resume(s))
    },
    Test("discardsAfterReboot") {
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 14, 40), calendar: paris)
        expectEqual(ResumePolicy.decide(SavedSession(session: s, bootTime: boot), bootTime: boot.addingTimeInterval(3600),
                                        now: now), .discard)
    },
    Test("discardsExpiredSession") {
        let s = Session.start(.minutes(15), keepDisplayOn: true, now: at(2026, 10, 14, 14, 0), calendar: paris)
        expectEqual(ResumePolicy.decide(SavedSession(session: s, bootTime: boot), bootTime: boot, now: now), .discard)
    },
    Test("encodeDecode") {
        let s = Session.start(.download, keepDisplayOn: false, now: now, calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot)
        expectEqual(SavedSession.decode(try saved.encoded()), saved)
        expect(SavedSession.decode(Data("pas du json".utf8)) == nil)
    },
])
