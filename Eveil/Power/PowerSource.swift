import Foundation
import IOKit.ps
import Observation

/// Alimentation : secteur ou batterie, charge de la batterie interne (nil sur un Mac de bureau),
/// mode Economie d'energie. Suivie par IOPowerSources et NSProcessInfoPowerStateDidChange ;
/// `onChange` est appele a chaque changement.
@MainActor
@Observable
final class PowerSource {
    static let shared = PowerSource()

    private(set) var onACPower = true
    private(set) var batteryPercent: Int?
    private(set) var lowPowerMode = false
    var hasBattery: Bool { batteryPercent != nil }

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() { refresh() }

    func start() {
        guard source == nil else { return }
        // Rappel C sans capture, appele sur la boucle principale (source ajoutee a la boucle principale).
        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            MainActor.assumeIsolated { PowerSource.shared.changed() }
        }, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            self.source = source
        }
        observer = NotificationCenter.default.addObserver(forName: Notification.Name.NSProcessInfoPowerStateDidChange,
                                                          object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { PowerSource.shared.changed() }
        }
    }

    private func changed() {
        refresh()
        onChange?()
    }

    func refresh() {
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return }
        let providing = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        onACPower = providing != kIOPSBatteryPowerValue
        var percent: Int?
        let list = (IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]) ?? []
        for item in list {
            guard let description = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let max = description[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            percent = Int((Double(current) / Double(max) * 100).rounded())
        }
        batteryPercent = percent
    }
}
