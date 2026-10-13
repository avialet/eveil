import Foundation
import EveilCore

/// Session << tant qu'un telechargement avance >> : releve toutes les 15 s des fichiers partiels des
/// navigateurs dans les dossiers surveilles (Telechargements par defaut, `EVEIL_DOWNLOADS_PATH` pour les
/// essais), confie a `PartialDownloads`. Lire Telechargements declenche la demande d'acces de macOS
/// au premier usage (NSDownloadsFolderUsageDescription).
@MainActor
final class DownloadsWatcher {
    static let shared = DownloadsWatcher()
    static let interval: TimeInterval = 15

    var onTick: (() -> Void)?
    private(set) var tracker: PartialDownloads?
    private var timer: Timer?

    var isRunning: Bool { tracker != nil }

    static var defaultFolder: URL {
        if let path = ProcessInfo.processInfo.environment["EVEIL_DOWNLOADS_PATH"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    /// Dossiers surveilles : Telechargements, puis ceux ajoutes dans les Reglages.
    static var folders: [URL] {
        let extra = (UserDefaults.standard.stringArray(forKey: Prefs.downloadFolders) ?? [])
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        return [defaultFolder] + extra.filter { $0.standardizedFileURL != defaultFolder.standardizedFileURL }
    }

    func start(since start: Date) {
        stop()
        tracker = PartialDownloads(start: start)
        scan()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                DownloadsWatcher.shared.scan()
                DownloadsWatcher.shared.onTick?()
            }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        tracker = nil
    }

    func isFinished(at date: Date) -> Bool { tracker?.isFinished(at: date) ?? false }
    func isActive(at date: Date) -> Bool { tracker?.isActive(at: date) ?? false }

    private func scan() {
        guard tracker != nil else { return }
        tracker?.record(Self.snapshot(of: Self.folders), at: Date())
    }

    /// Partiels a plat de chaque dossier (chemin -> taille ; somme du contenu pour un paquet Safari).
    nonisolated static func snapshot(of folders: [URL]) -> [String: Int64] {
        let fm = FileManager.default
        var result: [String: Int64] = [:]
        for folder in folders {
            guard let names = try? fm.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where PartialDownloads.isPartial(name) {
                let url = folder.appendingPathComponent(name)
                result[url.path] = size(of: url)
            }
        }
        return result
    }

    nonisolated static func size(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }
        guard values.isDirectory == true else { return Int64(values.fileSize ?? 0) }
        var total: Int64 = 0
        let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys))
        while let item = walker?.nextObject() as? URL {
            total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
        }
        return total
    }
}
