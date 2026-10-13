import AppKit
import SwiftUI
import VialetKit

/// Icone de barre des menus : le soleil levant du glyphe, creux au repos, demi-disque plein pendant
/// une session. Image template (teintee par la barre en clair comme en sombre).
enum SunIcon {
    /// Demi-disque du glyphe, ferme sur l'horizon.
    static let disc = "M 30 70 C 30 58.95 38.95 50 50 50 C 61.05 50 70 58.95 70 70 Z"

    /// Le soleil (x 14 a 86, y 30 a 70 dans la boite du glyphe) centre et large de `glyphWidth` points :
    /// le cadre de GlyphImage.template le rendrait trop petit a cote des symboles de la barre.
    static func image(filled: Bool, pointSize: CGFloat = 18, glyphWidth: CGFloat? = nil, stroke: CGFloat = 1.6) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let scale = (glyphWidth ?? pointSize - 2) / 72
        let side = 100 * scale
        let box = CGRect(x: pointSize / 2 - 50 * scale, y: pointSize / 2 - 50 * scale, width: side, height: side)
        let lineWidth = stroke
        let stroke = try? GlyphPath.cgPath(Brand.glyph, in: box)
        let fill = filled ? try? GlyphPath.cgPath(disc, in: box) : nil
        let image = NSImage(size: size, flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
            if let fill {
                ctx.addPath(fill)
                ctx.fillPath()
            }
            if let stroke {
                ctx.addPath(stroke)
                ctx.setLineWidth(lineWidth)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct MenuBarLabel: View {
    let active: Bool

    var body: some View {
        Image(nsImage: SunIcon.image(filled: active))
            .accessibilityLabel(active ? "\u{00C9}veil actif" : "\u{00C9}veil")
    }
}
