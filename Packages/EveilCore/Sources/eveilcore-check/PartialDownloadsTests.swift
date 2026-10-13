import Foundation
import EveilCore

private let t0 = at(2026, 10, 14, 15, 0)
private func t(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

let partialDownloadsTests: (String, [Test]) = ("PartialDownloads", [
    Test("recognizesPartialNames") {
        expect(PartialDownloads.isPartial("film.mov.download"))      // Safari
        expect(PartialDownloads.isPartial("image.iso.crdownload"))   // Chrome, Edge, Arc, Brave
        expect(PartialDownloads.isPartial("archive.zip.part"))       // Firefox
        expect(PartialDownloads.isPartial("ARCHIVE.ZIP.PART"))
        expect(!PartialDownloads.isPartial("rapport.pdf"))
        expect(!PartialDownloads.isPartial(".part"))
        expect(!PartialDownloads.isPartial("partition.txt"))
    },
    Test("baselineIsNotGrowth") {
        var d = PartialDownloads(start: t0)
        d.record(["a.part": 100], at: t(0))
        expect(!d.isActive(at: t(1)))
        expect(d.lastGrowth == nil)
    },
    Test("growthMakesActive") {
        var d = PartialDownloads(start: t0)
        d.record(["a.crdownload": 100], at: t(0))
        d.record(["a.crdownload": 5000], at: t(15))
        expectEqual(d.lastGrowth, t(15))
        expect(d.isActive(at: t(30)))
        expect(d.isActive(at: t(15 + 90)))
        expect(!d.isActive(at: t(15 + 91)))
    },
    Test("newPartialCountsAsGrowth") {
        var d = PartialDownloads(start: t0)
        d.record([:], at: t(0))
        d.record(["b.download": 0], at: t(15))
        expectEqual(d.lastGrowth, t(15))
    },
    Test("shrinkOrSameIsNotGrowth") {
        var d = PartialDownloads(start: t0)
        d.record(["a.part": 500], at: t(0))
        d.record(["a.part": 500], at: t(15))
        d.record(["a.part": 200], at: t(30))
        expect(d.lastGrowth == nil)
    },
    Test("finishedAfterGraceWithoutGrowth") {
        var d = PartialDownloads(start: t0)
        // Grace de 2 min depuis le debut : le temps de lancer le telechargement.
        expect(!d.isFinished(at: t(119)))
        expect(d.isFinished(at: t(120)))
        d.record(["a.part": 1], at: t(100))
        d.record(["a.part": 9], at: t(115))
        expect(!d.isFinished(at: t(115 + 119)))
        expect(d.isFinished(at: t(115 + 120)))
    },
    Test("abandonedPartialDoesNotKeepForever") {
        var d = PartialDownloads(start: t0)
        for i in 0..<20 { d.record(["vieux.crdownload": 4096], at: t(Double(i) * 15)) }
        expect(d.isFinished(at: t(300)))
    },
    Test("completedDownloadDisappears") {
        var d = PartialDownloads(start: t0)
        d.record(["a.part": 1], at: t(0))
        d.record(["a.part": 2], at: t(15))
        d.record([:], at: t(30))
        expectEqual(d.sizes, [:])
        expect(d.isFinished(at: t(15 + 120)))
    },
])
