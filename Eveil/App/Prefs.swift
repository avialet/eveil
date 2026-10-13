import Foundation
import EveilCore

/// Cles UserDefaults d'Eveil (prefixe `Eveil`) et leurs valeurs par defaut.
enum Prefs {
    /// Session en cours (`SavedSession`, JSON), pour la reprendre apres une relance ou une mise a jour.
    static let session = Brand.key("Session")
    /// << Garder l'ecran allume >>, memorise par famille (durees, conditions).
    static func keepDisplayOn(_ family: SessionFamily) -> String { Brand.key(family == .timed ? "DisplayTimed" : "DisplayCondition") }
    /// Derniere duree choisie, en minutes (0 : sans fin), pour le raccourci.
    static let lastTimed = Brand.key("LastTimed")
    /// Heure du choix << Jusqu'a... >>, en minutes depuis minuit.
    static let untilMinutes = Brand.key("UntilMinutes")
    /// Seuil de batterie (0 : jamais).
    static let batteryStopBelow = Brand.key("BatteryStopBelow")
    static let stopInLowPower = Brand.key("StopInLowPower")
    /// Dossiers surveilles en plus de Telechargements (chemins).
    static let downloadFolders = Brand.key("DownloadFolders")
    /// La session << telechargement >> a deja servi (la demande d'acces de macOS a eu lieu).
    static let downloadsUsed = Brand.key("DownloadsUsed")
    /// Raccourci facultatif, desactive par defaut.
    static let hotKeyEnabled = Brand.key("HotKeyEnabled")

    static func register() {
        UserDefaults.standard.register(defaults: [
            keepDisplayOn(.timed): SessionFamily.timed.defaultKeepsDisplayOn,
            keepDisplayOn(.condition): SessionFamily.condition.defaultKeepsDisplayOn,
            lastTimed: 60,
            untilMinutes: 18 * 60,
            batteryStopBelow: BatteryRules.standard.stopBelow ?? 0,
            stopInLowPower: BatteryRules.standard.stopInLowPowerMode,
            hotKeyEnabled: false,
        ])
    }

    static var batteryRules: BatteryRules {
        let d = UserDefaults.standard
        let below = d.integer(forKey: batteryStopBelow)
        return BatteryRules(stopBelow: below > 0 ? below : nil, stopInLowPowerMode: d.bool(forKey: stopInLowPower))
    }
}
