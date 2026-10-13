import AppKit

/// Apps ouvertes : liste pour le menu << une app tourne >> et lancement ou fermeture d'une app
/// (NSWorkspace, sans autorisation). `onChange` est appele a chaque lancement ou fermeture.
@MainActor
final class AppWatcher {
    static let shared = AppWatcher()

    struct RunningApp: Identifiable, Equatable {
        let bundleID: String
        let name: String
        var id: String { bundleID }
    }

    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { AppWatcher.shared.onChange?() }
            })
        }
    }

    func isRunning(_ bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).contains { !$0.isTerminated }
    }

    /// Apps ordinaires ouvertes (avec une icone dans le Dock), hors Eveil, par nom.
    func runningApps() -> [RunningApp] {
        let own = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningApp? in
                guard let id = app.bundleIdentifier, id != own, seen.insert(id).inserted else { return nil }
                return RunningApp(bundleID: id, name: app.localizedName ?? id)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Nom et identifiant d'une app choisie sur le disque.
    static func describe(appAt url: URL) -> RunningApp? {
        guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        return RunningApp(bundleID: id, name: name)
    }
}
