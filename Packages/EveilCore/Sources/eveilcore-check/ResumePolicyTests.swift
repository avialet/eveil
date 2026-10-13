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
    Test("relaunchRightAfterQuitResumes") {
        // Mise a jour : l'app quitte puis se relance dans la minute.
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 14, 40), calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot, quitAt: now.addingTimeInterval(-20))
        expectEqual(ResumePolicy.decide(saved, bootTime: boot, now: now), .resume(s))
    },
    Test("relaunchLongAfterQuitDiscards") {
        // Quitter arrete la session : une relance plus tard repart au repos.
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 14, 0), calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot, quitAt: now.addingTimeInterval(-ResumePolicy.relaunchWindow - 1))
        expectEqual(ResumePolicy.decide(saved, bootTime: boot, now: now), .discard)
    },
    Test("recentLastSeenResumesAfterCrash") {
        // Plantage : pas d'heure de sortie, mais la derniere trace a moins d'une minute.
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 14, 0), calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot, lastSeen: now.addingTimeInterval(-20))
        expectEqual(ResumePolicy.decide(saved, bootTime: boot, now: now), .resume(s))
    },
    Test("staleLastSeenDiscardsAfterOldCrash") {
        // Plantage ancien : pas de session fantome reprise des heures plus tard.
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 9, 0), calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot, lastSeen: now.addingTimeInterval(-ResumePolicy.relaunchWindow - 1))
        expectEqual(ResumePolicy.decide(saved, bootTime: boot, now: now), .discard)
    },
    Test("quitAtWinsOverLastSeen") {
        let s = Session.start(.indefinite, keepDisplayOn: true, now: at(2026, 10, 14, 9, 0), calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot, quitAt: now.addingTimeInterval(-10),
                                 lastSeen: now.addingTimeInterval(-3600))
        expectEqual(ResumePolicy.decide(saved, bootTime: boot, now: now), .resume(s))
    },
    Test("encodeDecode") {
        let s = Session.start(.download, keepDisplayOn: false, now: now, calendar: paris)
        let saved = SavedSession(session: s, bootTime: boot)
        expectEqual(SavedSession.decode(try saved.encoded()), saved)
        expect(SavedSession.decode(Data("pas du json".utf8)) == nil)
    },
])
