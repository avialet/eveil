import Foundation
import IOKit.pwr_mgt

/// Assertion d'energie IOKit : tant qu'elle vit, le Mac ne se met pas en veille d'inactivite.
/// `keepDisplayOn` : PreventUserIdleDisplaySleep (ecran allume, Mac eveille), sinon
/// PreventUserIdleSystemSleep (ecran libre de s'eteindre, Mac eveille). Relachee au `deinit` ; l'OS
/// la relache aussi a la mort du processus et, avec `timeout`, meme si l'app est figee.
/// Visible dans `pmset -g assertions` sous le nom << Eveil >> (avec accent).
final class PowerAssertion {
    static let name = "\u{00C9}veil"

    let id: IOPMAssertionID
    let keepsDisplayOn: Bool

    init?(keepDisplayOn: Bool, reason: String, timeout: TimeInterval?) {
        let type = keepDisplayOn ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
        var properties: [String: Any] = [
            kIOPMAssertionTypeKey: type,
            kIOPMAssertionLevelKey: NSNumber(value: kIOPMAssertionLevelOn),
            kIOPMAssertionNameKey: Self.name,
            kIOPMAssertionHumanReadableReasonKey: reason,
        ]
        if let timeout, timeout > 0 {
            properties[kIOPMAssertionTimeoutKey] = NSNumber(value: timeout)
            properties[kIOPMAssertionTimeoutActionKey] = kIOPMAssertionTimeoutActionRelease
        }
        var id = IOPMAssertionID(0)
        guard IOPMAssertionCreateWithProperties(properties as CFDictionary, &id) == kIOReturnSuccess else {
            NSLog("\(Self.name) : assertion d'energie refusee")
            return nil
        }
        self.id = id
        self.keepsDisplayOn = keepDisplayOn
    }

    deinit { IOPMAssertionRelease(id) }
}

/// Heure de demarrage du Mac (`kern.boottime`) : une session enregistree avant un redemarrage est abandonnee.
enum BootTime {
    static func current() -> Date? {
        var time = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &time, &size, nil, 0) == 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(time.tv_sec) + TimeInterval(time.tv_usec) / 1_000_000)
    }
}
