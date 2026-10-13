import AppKit
import EveilCore
import SwiftUI
import VialetKit

/// Reglages : cartes standard du kit (raccourci facultatif, toujours la, mises a jour, apparence), puis
/// Icone, Batterie, Telechargements et la note sur le capot ferme.
struct SettingsView: View {
    @AppStorage(Prefs.hotKeyEnabled) private var hotKeyEnabled = false

    var body: some View {
        SettingsScreen(app: Brand.identity, hotKey: HotKeyController.shared, updater: Updater.shared,
                       menuBar: nil,
                       hotKeyEnabled: Binding(get: { hotKeyEnabled }, set: { on in
                           hotKeyEnabled = on
                           EveilHotKey.apply(on)
                       }),
                       hotKeyHint: "Depuis n\u{2019}importe quelle app\u{00A0}: lance la derni\u{00E8}re dur\u{00E9}e choisie, ou arr\u{00EA}te.",
                       alwaysOnHint: "Fermer la fen\u{00EA}tre ne quitte pas \u{00C9}veil\u{00A0}: une session continue. \u{2318}Q quitte et arr\u{00EA}te la session.",
                       width: 480) {
            IconCard()
            if PowerSource.shared.hasBattery { BatteryCard() }
            DownloadsCard()
            LidNote()
        }
        .tint(Theme.accent)
    }
}

/// Raccourci facultatif : enregistre ou suspendu selon l'interrupteur.
@MainActor
enum EveilHotKey {
    static func apply(_ on: Bool) {
        if on {
            HotKeyController.shared.start { SessionController.shared.toggle() }
        } else {
            HotKeyController.shared.suspend()
        }
    }
}

/// Icone de barre des menus : Automatique (propre a Eveil : avec Vialet, visible seulement pendant une
/// session), Toujours, Jamais.
private struct IconCard: View {
    @State private var presence = MenuBarPresence.shared

    var body: some View {
        SettingsCard(icon: "menubar.rectangle", color: Theme.accent, title: "Ic\u{00F4}ne") {
            HStack {
                Text("Ic\u{00F4}ne dans la barre des menus")
                Spacer(minLength: 12)
                Picker("Ic\u{00F4}ne dans la barre des menus",
                       selection: Binding(get: { presence.mode }, set: { presence.mode = $0 })) {
                    ForEach(MenuBarMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            note(legend)
        }
    }

    private var legend: String {
        switch presence.mode {
        case .auto:
            presence.hubInstalled
                ? "Vialet est install\u{00E9}e\u{00A0}: l\u{2019}ic\u{00F4}ne n\u{2019}appara\u{00EE}t que pendant une session, pour voir l\u{2019}\u{00E9}tat et arr\u{00EA}ter en un clic."
                : "Visible tant que Vialet n\u{2019}est pas install\u{00E9}e\u{00A0}: soleil creux au repos, plein pendant une session."
        case .shown: "Toujours visible\u{00A0}: soleil creux au repos, plein pendant une session."
        case .hidden: "Jamais affich\u{00E9}e\u{00A0}: \u{00C9}veil reste accessible par le Dock, Vialet et eveil://."
        }
    }
}

private struct BatteryCard: View {
    @AppStorage(Prefs.batteryStopBelow) private var stopBelow = 20
    @AppStorage(Prefs.stopInLowPower) private var stopInLowPower = true

    var body: some View {
        SettingsCard(icon: "battery.50percent", color: Theme.pine, title: "Batterie") {
            Picker("Arr\u{00EA}ter sur batterie sous", selection: $stopBelow) {
                ForEach(BatteryRules.thresholds, id: \.self) { Text("\($0)\u{00A0}%").tag($0) }
                Text("Jamais").tag(0)
            }
            .fixedSize()
            .onChange(of: stopBelow) { SessionController.shared.evaluate() }
            Toggle("Arr\u{00EA}ter en mode \u{00C9}conomie d\u{2019}\u{00E9}nergie", isOn: $stopInLowPower)
                .onChange(of: stopInLowPower) { SessionController.shared.evaluate() }
            note("Sur secteur, la charge ne compte pas. Une session \u{00AB}\u{00A0}sur secteur\u{00A0}\u{00BB} s\u{2019}arr\u{00EA}te d\u{00E8}s qu\u{2019}on d\u{00E9}branche.")
        }
    }
}

private struct DownloadsCard: View {
    @State private var folders: [String] = UserDefaults.standard.stringArray(forKey: Prefs.downloadFolders) ?? []

    var body: some View {
        SettingsCard(icon: "arrow.down.circle", color: Theme.sea, title: "T\u{00E9}l\u{00E9}chargements") {
            VStack(alignment: .leading, spacing: 6) {
                folderRow(DownloadsWatcher.defaultFolder.path, removable: false)
                ForEach(folders, id: \.self) { folderRow($0, removable: true) }
            }
            Button("Ajouter un dossier\u{2026}") { add() }
                .controlSize(.small)
            note("\u{00C9}veil regarde si un fichier en cours de t\u{00E9}l\u{00E9}chargement grossit (Safari, Chrome, Edge, Arc, Brave, Firefox). La session s\u{2019}arr\u{00EA}te apr\u{00E8}s deux minutes sans progr\u{00E8}s. Aucun acc\u{00E8}s au r\u{00E9}seau.")
        }
    }

    private func folderRow(_ path: String, removable: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "folder").foregroundStyle(Theme.inkSoft)
            Text(FileManager.default.displayName(atPath: path)).font(Theme.ui(12.5, weight: .medium))
            Text((path as NSString).abbreviatingWithTildeInPath).font(Theme.ui(11)).foregroundStyle(Theme.inkFaint)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            if removable {
                Button { remove(path) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.plain).foregroundStyle(Theme.inkSoft)
                    .help("Ne plus surveiller ce dossier")
            }
        }
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Surveiller"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.standardizedFileURL.path
        guard path != DownloadsWatcher.defaultFolder.standardizedFileURL.path, !folders.contains(path) else { return }
        folders.append(path)
        UserDefaults.standard.set(folders, forKey: Prefs.downloadFolders)
    }

    private func remove(_ path: String) {
        folders.removeAll { $0 == path }
        UserDefaults.standard.set(folders, forKey: Prefs.downloadFolders)
    }
}

/// Capot ferme : ce que macOS permet, sans promesse.
private struct LidNote: View {
    var body: some View {
        SettingsCard(icon: "laptopcomputer", color: Theme.stone, title: "Capot ferm\u{00E9}") {
            note("Fermer le capot met le Mac en veille, session ou non\u{00A0}: macOS ne laisse aucune app l\u{2019}emp\u{00EA}cher. Avec un \u{00E9}cran externe et le chargeur branch\u{00E9}s, le Mac continue capot ferm\u{00E9} et \u{00C9}veil le garde \u{00E9}veill\u{00E9}.")
        }
    }
}

@MainActor
private func note(_ text: String) -> some View {
    Text(text)
        .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
        .fixedSize(horizontal: false, vertical: true)
}
