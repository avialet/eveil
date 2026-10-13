#if DEBUG
import AppKit
import EveilCore
import SwiftUI
import VialetKit

/// Mode capture sans ecran (voir SnapshotRunner) : `Eveil -EveilSnapshot <dossier>
/// [-EveilSnapshotAppearance dark] [-EveilSnapshotOnly a,b]`. Etats fictifs a heure fixe (aujourd'hui
/// 15 h 16), sans assertion, minuterie ni enregistrement. Ecrit `panel` (repos), `panel-actif` (1 h,
/// ecran allume), `panel-app` (tant que Keynote tourne, ecran libre), `panel-fin` (arret sur batterie),
/// `mainWindow`, `icones` (icone de barre des menus), `settings`, `about` et `update`, puis quitte.
extension AppDelegate {
    func runSnapshotIfRequested() -> Bool {
        guard Self.isSnapshot else { return false }
        let controller = SessionController.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        func time(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        let now = time(15, 16)
        let hour = Session(kind: .duration(minutes: 60), keepDisplayOn: true, start: time(14, 40), end: time(15, 40))
        let keynote = Session(kind: .app(bundleID: "com.apple.iWork.Keynote", name: "Keynote"), keepDisplayOn: false,
                              start: time(14, 5), appSeen: true)

        func panel(_ session: Session?, stop: SessionController.StopNote? = nil) -> SnapshotScenario.Body {
            {
                controller.preview(session: session, lastStop: stop, clock: now)
                let window = SnapshotPreview.window(EveilPanel(context: .menuBar))
                window.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(600))
                return window
            }
        }
        let own = [
            SnapshotScenario("panel", window: panel(nil)),
            SnapshotScenario("panel-actif", window: panel(hour)),
            SnapshotScenario("panel-app", window: panel(keynote)),
            SnapshotScenario("panel-fin", window: panel(nil, stop: .init(reason: .batteryLow(18), date: time(15, 2)))),
            SnapshotScenario("mainWindow") {
                controller.preview(session: hour, clock: now)
                MainWindowController.shared.show()
                try await Task.sleep(for: .seconds(1))
                return MainWindowController.shared.window
            },
            SnapshotScenario("icones") {
                let window = SnapshotPreview.window(IconBoard())
                window.orderFrontRegardless()
                try await Task.sleep(for: .milliseconds(300))
                return window
            },
        ]
        let standard = SnapshotRunner.standardScenarios(mainWindow: { MainWindowController.shared.window },
                                                        identity: Brand.identity)
            .filter { ["settings", "about", "update"].contains($0.name) }
        return SnapshotRunner.runIfRequested(prefix: Brand.name, scenarios: own + standard)
    }
}

extension SnapshotScenario {
    typealias Body = @MainActor () async throws -> NSWindow?
}

@MainActor
enum SnapshotPreview {
    /// Fenetre sans bord autour de `view`, coins arrondis comme le menu de la barre des menus.
    static func window<V: View>(_ view: V) -> NSWindow {
        let content = view.clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).padding(10)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear
        window.isOpaque = false
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: 80, y: 80))
        return window
    }
}

/// Icone de barre des menus au repos et pendant une session, sur une barre claire et une barre sombre,
/// a taille reelle puis agrandie.
private struct IconBoard: View {
    var body: some View {
        VStack(spacing: 10) {
            bar(light: true)
            bar(light: false)
        }
        .padding(14)
        .background(Theme.paper)
    }

    private func bar(light: Bool) -> some View {
        HStack(spacing: 22) {
            ForEach([false, true], id: \.self) { filled in
                HStack(spacing: 12) {
                    Image(nsImage: SunIcon.image(filled: filled)).renderingMode(.template)
                    Image(nsImage: SunIcon.image(filled: filled, pointSize: 72, glyphWidth: 62, stroke: 6.4)).renderingMode(.template)
                }
            }
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
        }
        .foregroundStyle(light ? Color.black.opacity(0.85) : Color.white)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(light ? Color(white: 0.93) : Color(white: 0.16)))
    }
}
#endif
