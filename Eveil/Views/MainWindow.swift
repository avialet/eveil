import AppKit
import SwiftUI
import VialetKit

/// Fenetre principale (Dock, `eveil://open`) : le bandeau de mise a jour puis le panneau. Fenetre AppKit
/// (identifiant `main`, trouvee par WindowSummoner) : elle ne s'ouvre pas d'elle-meme au lancement, ce
/// qui laisse `open -g eveil://1h` ou l'ouverture a la connexion sans fenetre.
@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private(set) var window: NSWindow?

    func install() {
        WindowSummoner.openMainWindow = { MainWindowController.shared.show() }
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.unhide(nil)
        NSApp.activate()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let content = VStack(spacing: 0) {
            UpdateNotice(updater: .shared)
            EveilPanel(context: .window)
        }
        .frame(width: EveilPanel.width)
        .background(Theme.paper)
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.title = Brand.displayName
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(Theme.paper)
        window.contentView = hosting
        // Taille du contenu (la fenetre suit ensuite le panneau qui se deplie), centree a l'ouverture.
        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        window.setContentSize(fitting.width > 0 && fitting.height > 0 ? fitting : NSSize(width: EveilPanel.width, height: 520))
        window.center()
        return window
    }
}

/// Ouvre les Reglages (scene Settings) par l'entree << Reglages... >> du menu de l'app.
@MainActor
enum SettingsOpener {
    static func open() {
        NSApp.activate()
        if let (menu, index) = item(in: NSApp.mainMenu) {
            menu.performActionForItem(at: index)
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private static func item(in menu: NSMenu?) -> (NSMenu, Int)? {
        guard let menu else { return nil }
        for (index, item) in menu.items.enumerated() {
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask == .command { return (menu, index) }
            if let found = self.item(in: item.submenu) { return found }
        }
        return nil
    }
}
