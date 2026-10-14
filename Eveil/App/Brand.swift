import SwiftUI
import VialetKit

/// Identite de l'app : le seul fichier Swift qui connait son nom, ses teintes et son glyphe.
enum Brand {
    static let name = "Eveil"
    static let displayName = "Éveil"
    /// Teintes de l'affiche (sites, plaques, DMG, interface), calculees par scripts/teintes.py :
    /// texte `deep` sur `background`. Une teinte par ligne `cle: 0x...` (lue par les scripts du socle).
    static let palette = AccentPalette(accent: 0x12A3B0, background: 0x12A3B0,
                                       deep: 0x043237, pale: 0xDCF8FB,
                                       night: 0x001F23, nightInk: 0xA9E4EA)
    /// Pictogramme de la plaque : sous-ensemble SVG absolu (M L H V C Q Z), boite 0-100, trait non rempli.
    /// Soleil levant : horizon, demi-disque et trois rayons.
    static let glyph = "M 14 70 H 86 M 30 70 C 30 58.95 38.95 50 50 50 C 61.05 50 70 58.95 70 70 M 50 30 V 40 M 22 42 L 29 49 M 78 42 L 71 49"
    /// Trait du glyphe en `deep` plutot qu'en blanc (accent trop clair pour un trait blanc).
    static let strokeDeep = false
    static let identity = AppIdentity(name: name, displayName: displayName, repository: "avialet/eveil",
                                      bundleIdentifier: "fr.vialet.eveil", palette: palette, glyph: glyph,
                                      strokeDeep: strokeDeep)
    static let updater = UpdaterConfiguration(identity)

    /// Cles UserDefaults, prefixees par le nom de l'app.
    static func key(_ suffix: String) -> String { identity.key(suffix) }
}

extension Updater {
    static let shared = Updater(configuration: Brand.updater)
}

extension HotKeyController {
    /// Facultatif (desactive par defaut, `EveilHotKeyEnabled`) : Ctrl-Maj-Cmd-Espace bascule entre la
    /// derniere duree et l'arret. Libre parmi les apps vialet.app.
    static let shared = HotKeyController(defaultsKey: Brand.key("HotKey"), logName: Brand.displayName,
                                         initial: .space([.control, .shift, .command]))
}

extension MenuBarPresence {
    static let shared = MenuBarPresence(app: Brand.identity)
}

/// Icone du Dock : seulement pendant qu'une fenetre est ouverte (reglage Toujours).
extension DockPresence {
    static let shared = DockPresence(app: Brand.identity)
}

/// Phrase des Reglages sur les echanges reseau : l'app peut tenir le menu rassembleur des apps vialet.app.
extension HubPresence {
    static let updateNote = "\u{00C9}changes r\u{00E9}seau de \(Brand.displayName) : la derni\u{00E8}re version publi\u{00E9}e sur GitHub et, quand son ic\u{00F4}ne rassemble vos apps vialet.app, celle de ces apps et le catalogue de vialet.app une fois par jour. Aucune donn\u{00E9}e n'est envoy\u{00E9}e."
}

extension AppActions {
    /// `eveil://` et `eveil://open` montrent la fenetre ; `eveil://update` cherche une mise a jour.
    static let shared = AppActions(Brand.identity, open: { MainWindowController.shared.show() },
                                   checkForUpdates: { MainWindowController.shared.show(); Updater.shared.check() })
}
