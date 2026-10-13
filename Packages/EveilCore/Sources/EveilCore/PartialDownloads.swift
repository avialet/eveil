import Foundation

/// Heuristique << tant qu'un telechargement avance >> : releves successifs des fichiers partiels des
/// navigateurs (nom -> taille). Actif si un partiel a grossi (ou est apparu) dans les 90 dernieres
/// secondes ; fini apres 2 min sans croissance (depuis le debut de la session s'il n'y en a eu aucune).
/// Un partiel abandonne ne grossit plus : il ne tient pas le Mac eveille.
public struct PartialDownloads: Equatable, Sendable {
    public static let activeWindow: TimeInterval = 90
    public static let grace: TimeInterval = 120
    /// Safari (paquet), Chrome, Edge, Arc, Brave, Firefox.
    public static let extensions = ["download", "crdownload", "part"]

    public let start: Date
    public private(set) var sizes: [String: Int64] = [:]
    public private(set) var lastGrowth: Date?
    private var hasBaseline = false

    public init(start: Date) { self.start = start }

    public static func isPartial(_ name: String) -> Bool {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return false }
        let ext = name[name.index(after: dot)...].lowercased()
        return extensions.contains(ext)
    }

    /// Nouveau releve. Le premier sert de reference (un partiel deja la n'est pas une croissance).
    public mutating func record(_ snapshot: [String: Int64], at date: Date) {
        if hasBaseline {
            let grew = snapshot.contains { name, size in
                guard let previous = sizes[name] else { return true }
                return size > previous
            }
            if grew { lastGrowth = date }
        }
        hasBaseline = true
        sizes = snapshot
    }

    public func isActive(at now: Date) -> Bool {
        guard let lastGrowth else { return false }
        return now.timeIntervalSince(lastGrowth) <= Self.activeWindow
    }

    public func isFinished(at now: Date) -> Bool {
        now.timeIntervalSince(lastGrowth ?? start) >= Self.grace
    }
}
