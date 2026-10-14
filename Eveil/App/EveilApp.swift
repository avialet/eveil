import SwiftUI
import VialetKit

@main
struct EveilApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var presence = MenuBarPresence.shared
    @State private var controller = SessionController.shared

    /// Teintes de l'app avant le premier rendu (et police Bricolage Grotesque des titres).
    init() { Theme.configure(Brand.palette) }

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            AboutCommands(identity: Brand.identity)
            UpdateCommands(updater: .shared)
        }

        MenuBarExtra(isInserted: menuBarInserted) {
            EveilPanel(context: .menuBar)
        } label: {
            MenuBarLabel(active: controller.isActive)
        }
        .menuBarExtraStyle(.window)
    }

    /// Mode Automatique propre a Eveil : seule app vialet.app, l'icone est toujours la ; rassemblee (par
    /// Vialet ou l'icone vialet.app d'une autre app), seulement pendant une session (indicateur et arret en un clic). Toujours et Jamais comme dans les autres apps.
    /// Retirer l'icone de la barre (Cmd-glisser) passe en Jamais.
    private var menuBarInserted: Binding<Bool> {
        let presence = presence, controller = controller
        return Binding(get: {
            Self.inserted(presence, active: controller.isActive)
        }, set: { newValue in
            guard newValue != Self.inserted(presence, active: controller.isActive) else { return }
            presence.mode = newValue ? .shown : .hidden
        })
    }

    @MainActor
    private static func inserted(_ presence: MenuBarPresence, active: Bool) -> Bool {
        guard !AppDelegate.isSnapshot else { return false }
        switch presence.mode {
        case .shown: return true
        case .hidden: return false
        case .auto: return presence.isInserted || active
        }
    }
}
