import Foundation
import EveilCore

private let t0 = at(2026, 10, 14, 15, 0)
private func session(_ choice: SessionChoice) -> Session {
    Session.start(choice, keepDisplayOn: true, now: t0, calendar: paris)
}
private func signals(_ minutes: Double = 1, onAC: Bool = true, battery: Int? = nil, lowPower: Bool = false,
                     appRunning: Bool = false, downloadsFinished: Bool = false) -> Signals {
    Signals(now: t0.addingTimeInterval(minutes * 60), onACPower: onAC, batteryPercent: battery,
            lowPowerMode: lowPower, appRunning: appRunning, downloadsFinished: downloadsFinished)
}
private let rules = BatteryRules(stopBelow: 20, stopInLowPowerMode: true)

let evaluatorTests: (String, [Test]) = ("Evaluator", [
    Test("timedKeepsUntilEnd") {
        let s = session(.minutes(60))
        expectEqual(Evaluator.evaluate(s, signals(59), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(60), rules: rules), .stop(.ended))
        expectEqual(Evaluator.evaluate(s, signals(600), rules: rules), .stop(.ended))
    },
    Test("indefiniteKeeps") {
        expectEqual(Evaluator.evaluate(session(.indefinite), signals(60 * 24 * 3), rules: rules), .keep)
    },
    Test("batteryRuleOnlyOnBattery") {
        let s = session(.indefinite)
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 19), rules: rules), .stop(.batteryLow(19)))
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 20), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(onAC: true, battery: 5), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 5),
                                       rules: BatteryRules(stopBelow: nil, stopInLowPowerMode: false)), .keep)
    },
    Test("desktopMacWithoutBatteryIgnoresRule") {
        expectEqual(Evaluator.evaluate(session(.indefinite), signals(onAC: false, battery: nil), rules: rules), .keep)
    },
    Test("lowPowerMode") {
        let s = session(.minutes(60))
        expectEqual(Evaluator.evaluate(s, signals(lowPower: true), rules: rules), .stop(.lowPowerMode))
        expectEqual(Evaluator.evaluate(s, signals(lowPower: true),
                                       rules: BatteryRules(stopBelow: 20, stopInLowPowerMode: false)), .keep)
    },
    Test("lowPowerAlreadyOnAtStartIsAccepted") {
        // Demander une session en mode Economie d'energie : c'est voulu, on ne l'arrete que s'il s'active ensuite.
        var s = session(.minutes(60))
        s.startedInLowPower = true
        expectEqual(Evaluator.evaluate(s, signals(lowPower: true), rules: rules), .keep)
    },
    Test("batteryAlreadyLowAtStartIsAccepted") {
        // Lancee a 15 % avec un seuil de 20 % : voulu ; macOS gere la batterie critique.
        var s = session(.indefinite)
        s.batteryAtStart = 15
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 12), rules: rules), .keep)
        s.batteryAtStart = 40
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 19), rules: rules), .stop(.batteryLow(19)))
    },
    Test("endBeatsBattery") {
        expectEqual(Evaluator.evaluate(session(.minutes(15)), signals(20, onAC: false, battery: 3), rules: rules),
                    .stop(.ended))
    },
    Test("powerSessionStopsWhenUnplugged") {
        let s = session(.power)
        expectEqual(Evaluator.evaluate(s, signals(onAC: true), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(onAC: false, battery: 80), rules: rules), .stop(.unplugged))
    },
    Test("appSessionWaitsThenFollowsApp") {
        var s = session(.app(bundleID: "com.apple.TextEdit", name: "TextEdit"))
        // Pas encore vue : on attend son lancement.
        expectEqual(Evaluator.evaluate(s, signals(appRunning: false), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(appRunning: true), rules: rules), .keep)
        s.appSeen = true
        expectEqual(Evaluator.evaluate(s, signals(appRunning: false), rules: rules), .stop(.appQuit("TextEdit")))
    },
    Test("downloadSession") {
        let s = session(.download)
        expectEqual(Evaluator.evaluate(s, signals(downloadsFinished: false), rules: rules), .keep)
        expectEqual(Evaluator.evaluate(s, signals(downloadsFinished: true), rules: rules), .stop(.downloadsDone))
        // Le signal ne concerne que la session de telechargement.
        expectEqual(Evaluator.evaluate(session(.indefinite), signals(downloadsFinished: true), rules: rules), .keep)
    },
    Test("batteryChoices") {
        expectEqual(BatteryRules.thresholds, [10, 20, 30])
        expectEqual(BatteryRules.standard, BatteryRules(stopBelow: 20, stopInLowPowerMode: true))
    },
])
