import AppKit
import EveilCore
import SwiftUI
import VialetKit

/// Panneau unique d'Eveil : carte d'etat, durees, conditions. Le meme dans le menu de l'icone de
/// barre des menus et dans la fenetre (Dock, `eveil://open`).
struct EveilPanel: View {
    enum Context { case menuBar, window }
    static let width: CGFloat = 320

    let context: Context
    @State private var controller = SessionController.shared
    @State private var power = PowerSource.shared
    @State private var showUntil = false
    @State private var showApps = false
    @State private var runningApps: [AppWatcher.RunningApp] = []
    @AppStorage(Prefs.untilMinutes) private var untilMinutes = 18 * 60
    @AppStorage(Prefs.downloadsUsed) private var downloadsUsed = false

    var body: some View {
        VStack(spacing: 0) {
            StatusCard()
                .padding([.horizontal, .top], 12)
            VStack(alignment: .leading, spacing: 16) {
                durations
                conditions
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            Divider().overlay(Theme.line)
            footer
        }
        .frame(width: Self.width)
        .background(Theme.paper)
        .fontDesign(.rounded)
        .tint(Theme.accent)
    }

    // MARK: Durees

    private var durations: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Dur\u{00E9}e")
            HStack(spacing: 6) {
                chip("15\u{00A0}min", .minutes(15))
                chip("1\u{00A0}h", .minutes(60))
                chip("2\u{00A0}h", .minutes(120))
                chip("Sans fin", .indefinite)
            }
            ConditionRow(icon: "clock", title: "jusqu\u{2019}\u{00E0} une heure pr\u{00E9}cise", detail: untilDetail,
                         selected: controller.session?.kind == .until || showUntil,
                         disclosure: showUntil ? .open : .closed) {
                withAnimation(.snappy(duration: 0.2)) { showUntil.toggle() }
            }
            .padding(.top, 2)
            if showUntil { untilRow.transition(.opacity.combined(with: .move(edge: .top))) }
        }
    }

    private var untilDetail: String? {
        guard controller.session?.kind == .until, let end = controller.session?.end else { return nil }
        return StatusText.endTime(end, now: controller.now, calendar: controller.calendar)
    }

    private func chip(_ title: String, _ choice: SessionChoice) -> some View {
        DurationChip(title: title, selected: isSelected(choice)) {
            controller.start(choice)
            showUntil = false
        }
    }

    private var untilDate: Binding<Date> {
        Binding(get: {
            Calendar.current.date(bySettingHour: untilMinutes / 60, minute: untilMinutes % 60, second: 0, of: controller.now)
                ?? controller.now
        }, set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            untilMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
    }

    private var untilRow: some View {
        let end = EndClock.nextOccurrence(hour: untilMinutes / 60, minute: untilMinutes % 60,
                                          after: controller.now, calendar: Calendar.current)
        return HStack(spacing: 10) {
            DatePicker("Heure de fin", selection: untilDate, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.stepperField)
                .environment(\.locale, Locale(identifier: "fr_FR"))
            Text(StatusText.endTime(end, now: controller.now, calendar: Calendar.current))
                .font(Theme.ui(12)).foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button("D\u{00E9}marrer") {
                controller.start(.until(hour: untilMinutes / 60, minute: untilMinutes % 60))
                withAnimation(.snappy(duration: 0.2)) { showUntil = false }
            }
            .controlSize(.small)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.ink.opacity(0.04)))
        .padding(.leading, 38)
    }

    // MARK: Conditions

    private var conditions: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader("Tant que\u{2026}")
            VStack(spacing: 2) {
                ConditionRow(icon: "arrow.down.circle", title: "un t\u{00E9}l\u{00E9}chargement avance",
                             detail: downloadDetail, selected: isSelected(.download)) {
                    controller.start(.download)
                }
                ConditionRow(icon: "app.badge.checkmark", title: "une app tourne", detail: appDetail,
                             selected: isAppSession || showApps, disclosure: showApps ? .open : .closed) {
                    if !showApps { runningApps = AppWatcher.shared.runningApps() }
                    withAnimation(.snappy(duration: 0.2)) { showApps.toggle() }
                }
                if showApps { appChoices.transition(.opacity.combined(with: .move(edge: .top))) }
                if power.hasBattery {
                    ConditionRow(icon: "powerplug", title: "le Mac est sur secteur",
                                 detail: power.onACPower ? nil : "Branchez le chargeur pour ce choix.",
                                 selected: isSelected(.power)) {
                        controller.start(.power)
                    }
                    .disabled(!power.onACPower && !isSelected(.power))
                }
            }
        }
    }

    private var downloadDetail: String? {
        if isSelected(.download) {
            return controller.downloadActive ? "Un t\u{00E9}l\u{00E9}chargement avance." : "En attente d\u{2019}un t\u{00E9}l\u{00E9}chargement\u{2026}"
        }
        return downloadsUsed ? nil : "macOS demandera l\u{2019}acc\u{00E8}s \u{00E0} T\u{00E9}l\u{00E9}chargements."
    }

    private var isAppSession: Bool {
        if case .app = controller.session?.kind { return true }
        return false
    }

    private var appDetail: String? {
        if case .app(_, let name) = controller.session?.kind { return name }
        return nil
    }

    private var appChoices: some View {
        FlowLayout(spacing: 6) {
            ForEach(runningApps.prefix(12)) { app in
                ChipButton(app.name, color: Theme.accent, selected: isSelected(.app(bundleID: app.bundleID, name: app.name))) {
                    controller.start(.app(bundleID: app.bundleID, name: app.name))
                    showApps = false
                }
            }
            ChipButton("Choisir\u{2026}", icon: "folder", color: Theme.accent, selected: false) { chooseApp() }
        }
        .padding(.leading, 40).padding(.vertical, 4)
    }

    private func chooseApp() {
        NSApp.activate()
        let panel = NSOpenPanel()
        panel.title = "Tant que cette app tourne"
        panel.prompt = "Choisir"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let app = AppWatcher.describe(appAt: url) else { return }
        controller.start(.app(bundleID: app.bundleID, name: app.name))
        showApps = false
    }

    // MARK: Pied

    private var footer: some View {
        HStack(spacing: 14) {
            Wordmark.Mini(Brand.displayName)
            Spacer()
            FooterButton(symbol: "gearshape", help: "R\u{00E9}glages\u{2026}") { SettingsOpener.open() }
            if context == .menuBar {
                FooterButton(symbol: "macwindow", help: "Ouvrir la fen\u{00EA}tre") { MainWindowController.shared.show() }
                FooterButton(symbol: "power", help: "Quitter \u{00C9}veil") { NSApp.terminate(nil) }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func isSelected(_ choice: SessionChoice) -> Bool {
        guard let kind = controller.session?.kind else { return false }
        switch (choice, kind) {
        case (.minutes(let a), .duration(let b)): return a == b
        case (.until, .until), (.indefinite, .indefinite), (.download, .download), (.power, .power): return true
        case (.app(let a, _), .app(let b, _)): return a == b
        default: return false
        }
    }
}

// MARK: - Carte d'etat

/// Soleil, phrase d'etat, fin et barre d'avancement ; pendant une session, ecran, Arreter et +1 h.
private struct StatusCard: View {
    @State private var controller = SessionController.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 20)) { _ in
            content(now: controller.now)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let session = controller.session
        let active = session != nil
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                sun(active: active)
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.map { StatusText.headline($0, now: now, calendar: controller.calendar) } ?? "Au repos")
                        .font(Theme.display(16, weight: .semibold))
                        .foregroundStyle(active ? strong : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail(session, now: now))
                        .font(Theme.ui(12))
                        .foregroundStyle(active ? soft : Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if let session {
                if let end = session.end {
                    ProgressTrack(fraction: EndClock.progress(start: session.start, end: end, now: now), color: strong)
                }
                controls(session)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(active ? tint : Theme.card))
        .overlay(shape.strokeBorder(active ? strong.opacity(0.12) : Theme.line, lineWidth: 1))
        .animation(.snappy(duration: 0.25), value: active)
    }

    /// Fond et encres de la carte active : pale et deep en clair, nuit et encre de nuit en sombre.
    private var tint: Color { scheme == .dark ? Theme.accentNight : Theme.accentPale }
    private var strong: Color { scheme == .dark ? Theme.accentNightInk : Theme.accentDeep }
    private var soft: Color { strong.opacity(0.75) }

    private func sun(active: Bool) -> some View {
        Group {
            if active {
                Image(nsImage: GlyphImage.plate(Brand.palette, glyph: Brand.glyph, pixels: 96))
                    .resizable()
            } else {
                Image(nsImage: SunIcon.image(filled: false, pointSize: 44, glyphWidth: 28, stroke: 2.4))
                    .renderingMode(.template)
                    .foregroundStyle(Theme.inkSoft)
                    .background(RoundedRectangle(cornerRadius: 44 * 0.2245, style: .continuous).fill(Theme.ink.opacity(0.06)))
            }
        }
        .frame(width: 44, height: 44)
    }

    private func detail(_ session: Session?, now: Date) -> String {
        guard let session else {
            if let stop = controller.lastStop {
                return StatusText.stopped(stop.reason, at: stop.date, calendar: controller.calendar)
            }
            return StatusText.idle + "."
        }
        var parts: [String] = []
        if let end = session.end { parts.append(StatusText.remaining(end.timeIntervalSince(now))) }
        parts.append(StatusText.display(session.keepDisplayOn))
        let text = parts.joined(separator: " \u{00B7} ")
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    private func controls(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Garder l\u{2019}\u{00E9}cran allum\u{00E9}").font(Theme.ui(12.5, weight: .semibold))
                        .foregroundStyle(strong)
                    Text(session.keepDisplayOn
                         ? "Il ne s\u{2019}\u{00E9}teint pas, ni ne se verrouille."
                         : "Il s\u{2019}\u{00E9}teint ; le Mac reste \u{00E9}veill\u{00E9}.")
                        .font(Theme.ui(11)).foregroundStyle(soft)
                }
                Spacer(minLength: 4)
                Toggle("Garder l\u{2019}\u{00E9}cran allum\u{00E9}",
                       isOn: Binding(get: { session.keepDisplayOn }, set: { controller.setKeepDisplayOn($0) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            HStack(spacing: 8) {
                Button { controller.stop() } label: {
                    Label("Arr\u{00EA}ter", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(CardButtonStyle(fill: strong, text: tint))
                if session.canExtend {
                    Button { controller.extend() } label: {
                        Label("+1\u{00A0}h", systemImage: "plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CardButtonStyle(fill: strong.opacity(0.1), text: strong))
                    .frame(width: 92)
                }
            }
        }
    }
}

/// Pastille de duree, de largeur egale a ses voisines.
private struct DurationChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(12.5, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color.white : Theme.ink)
                .background(Capsule().fill(selected ? AnyShapeStyle(Theme.accent.gradient)
                                           : AnyShapeStyle(hovering ? Theme.accent.opacity(0.16) : Theme.ink.opacity(0.05))))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: selected)
    }
}

/// Bouton plein de la carte active (Arreter, +1 h).
private struct CardButtonStyle: ButtonStyle {
    let fill: Color
    let text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(Theme.ui(12.5, weight: .semibold))
            .foregroundStyle(text)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}

/// Fine barre d'avancement de la duree.
private struct ProgressTrack: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.14))
                Capsule().fill(color).frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 4)
        .animation(.snappy, value: fraction)
    }
}

// MARK: - Ligne de condition

private struct ConditionRow: View {
    enum Disclosure { case none, closed, open }

    let icon: String
    let title: String
    var detail: String?
    let selected: Bool
    var disclosure: Disclosure = .none
    let action: () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : Theme.accent)
                    .frame(width: 26, height: 26)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.icon, style: .continuous)
                        .fill(selected ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Theme.accent.opacity(0.13))))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.ui(13, weight: .medium)).foregroundStyle(Theme.ink)
                    if let detail {
                        Text(detail).font(Theme.ui(11)).foregroundStyle(Theme.inkSoft)
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                switch disclosure {
                case .none:
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                    }
                case .closed, .open:
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(disclosure == .open ? 90 : 0))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous)
                .fill(hovering && enabled ? Theme.ink.opacity(0.05) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.5)
        .onHover { hovering = $0 }
    }
}

private struct FooterButton: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? Theme.ink : Theme.inkSoft)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
    }
}
