import Foundation
import EveilCore

private let nbsp = "\u{00A0}"
private let now = at(2026, 10, 14, 14, 40)
private func session(_ choice: SessionChoice, display: Bool = true) -> Session {
    Session.start(choice, keepDisplayOn: display, now: now, calendar: paris)
}

let statusTextTests: (String, [Test]) = ("StatusText", [
    Test("timeUsesFrenchHours") {
        expectEqual(StatusText.time(at(2026, 10, 14, 15, 40), calendar: paris), "15\(nbsp)h\(nbsp)40")
        expectEqual(StatusText.time(at(2026, 10, 14, 9, 0), calendar: paris), "9\(nbsp)h")
        expectEqual(StatusText.time(at(2026, 10, 14, 9, 5), calendar: paris), "9\(nbsp)h\(nbsp)05")
        expectEqual(StatusText.time(at(2026, 10, 14, 0, 30), calendar: paris), "0\(nbsp)h\(nbsp)30")
    },
    Test("headlineTimedToday") {
        expectEqual(StatusText.headline(session(.minutes(60)), now: now, calendar: paris),
                    "\u{00C9}veill\u{00E9} jusqu\u{2019}\u{00E0} 15\(nbsp)h\(nbsp)40")
    },
    Test("headlineTimedTomorrow") {
        let s = Session.start(.until(hour: 9, minute: 0), keepDisplayOn: true, now: at(2026, 10, 14, 22, 0), calendar: paris)
        expectEqual(StatusText.headline(s, now: at(2026, 10, 14, 22, 0), calendar: paris),
                    "\u{00C9}veill\u{00E9} jusqu\u{2019}\u{00E0} demain 9\(nbsp)h")
    },
    Test("headlineLaterDayUsesWeekday") {
        var s = session(.minutes(60))
        s.extend(by: 2 * 24 * 3600)
        expectEqual(StatusText.headline(s, now: now, calendar: paris),
                    "\u{00C9}veill\u{00E9} jusqu\u{2019}\u{00E0} vendredi 15\(nbsp)h\(nbsp)40")
    },
    Test("headlineOpenEnded") {
        expectEqual(StatusText.headline(session(.indefinite), now: now, calendar: paris),
                    "\u{00C9}veill\u{00E9} jusqu\u{2019}\u{00E0} nouvel ordre")
        expectEqual(StatusText.headline(session(.download), now: now, calendar: paris),
                    "\u{00C9}veill\u{00E9} tant qu\u{2019}un t\u{00E9}l\u{00E9}chargement avance")
        expectEqual(StatusText.headline(session(.power), now: now, calendar: paris),
                    "\u{00C9}veill\u{00E9} tant que le Mac est sur secteur")
    },
    Test("headlineApp") {
        var s = session(.app(bundleID: "com.apple.iWork.Keynote", name: "Keynote"))
        expectEqual(StatusText.headline(s, now: now, calendar: paris), "\u{00C9}veill\u{00E9} en attendant Keynote")
        s.appSeen = true
        expectEqual(StatusText.headline(s, now: now, calendar: paris), "\u{00C9}veill\u{00E9} tant que Keynote tourne")
    },
    Test("display") {
        expectEqual(StatusText.display(true), "\u{00C9}cran allum\u{00E9}")
        expectEqual(StatusText.display(false), "\u{00C9}cran libre de s\u{2019}\u{00E9}teindre")
    },
    Test("remaining") {
        expectEqual(StatusText.remaining(72 * 60), "encore 1\(nbsp)h\(nbsp)12")
        expectEqual(StatusText.remaining(3600), "encore 1\(nbsp)h")
        expectEqual(StatusText.remaining(5 * 60 + 1), "encore 6\(nbsp)min")
        expectEqual(StatusText.remaining(40), "moins d\u{2019}une minute")
    },
    Test("stopped") {
        let t = at(2026, 10, 14, 15, 40)
        expectEqual(StatusText.stopped(.ended, at: t, calendar: paris), "Termin\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40")
        expectEqual(StatusText.stopped(.batteryLow(18), at: t, calendar: paris),
                    "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40\(nbsp): batterie \u{00E0} 18\(nbsp)%")
        expectEqual(StatusText.stopped(.appQuit("TextEdit"), at: t, calendar: paris),
                    "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40\(nbsp): TextEdit a \u{00E9}t\u{00E9} quitt\u{00E9}")
        expectEqual(StatusText.stopped(.unplugged, at: t, calendar: paris),
                    "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40\(nbsp): chargeur d\u{00E9}branch\u{00E9}")
        expectEqual(StatusText.stopped(.downloadsDone, at: t, calendar: paris),
                    "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40\(nbsp): plus de t\u{00E9}l\u{00E9}chargement en cours")
        expectEqual(StatusText.stopped(.lowPowerMode, at: t, calendar: paris),
                    "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40\(nbsp): mode \u{00C9}conomie d\u{2019}\u{00E9}nergie")
        expectEqual(StatusText.stopped(.user, at: t, calendar: paris), "Arr\u{00EA}t\u{00E9} \u{00E0} 15\(nbsp)h\(nbsp)40")
    },
    Test("hubStatus") {
        expectEqual(StatusText.hub(nil, now: now, calendar: paris), HubStatus(text: "", active: false))
        let hub = StatusText.hub(session(.minutes(60)), now: now, calendar: paris)
        expect(hub.active)
        expectEqual(hub.text, "\u{00C9}veill\u{00E9} jusqu\u{2019}\u{00E0} 15\(nbsp)h\(nbsp)40")
        let long = StatusText.hub(session(.app(bundleID: "x", name: String(repeating: "Tr\u{00E8}s long nom ", count: 8))),
                                  now: now, calendar: paris)
        expectEqual(long.text.count, HubStatus.maxLength)
        expect(long.text.hasSuffix("\u{2026}"))
    },
])
