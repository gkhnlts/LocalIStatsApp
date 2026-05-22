import Foundation
import IOKit
import IOKit.ps

public class BatteryMonitor: ObservableObject {
    @Published public var percentage: Double = 100.0
    @Published public var isCharging: Bool = false
    @Published public var powerSource: String = "AC Gücü"
    @Published public var timeRemainingFormatted: String = "Sınırsız"
    @Published public var health: String = "İyi"
    @Published public var hasBattery: Bool = true

    // Extended battery info
    @Published public var cycleCount: Int = 0
    @Published public var designCapacity: Int = 0
    @Published public var maxCapacity: Int = 0
    @Published public var currentCapacity: Int = 0
    @Published public var voltage: Double = 0.0      // millivolts → volts
    @Published public var amperage: Double = 0.0     // milliamps → amps
    @Published public var wattage: Double = 0.0      // computed: V × A
    @Published public var healthPercent: Double = 0.0 // maxCapacity / designCapacity

    public init() { update() }

    public func update() {
        updatePowerSources()
        updateIOKit()
    }

    private func updatePowerSources() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            hasBattery = false; powerSource = "AC Gücü"
            percentage = 100.0; isCharging = false
            timeRemainingFormatted = "N/A"
            return
        }
        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            hasBattery = false; powerSource = "AC Gücü"
            percentage = 100.0; isCharging = false
            timeRemainingFormatted = "N/A"
            return
        }
        hasBattery = true

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else { continue }

            let cap    = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey]     as? Int ?? 100
            if maxCap > 0 { self.percentage = (Double(cap) / Double(maxCap)) * 100.0 }

            self.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false

            let state = desc[kIOPSPowerSourceStateKey] as? String ?? kIOPSACPowerValue
            self.powerSource = state == kIOPSACPowerValue ? "AC Gücü" : "Pil Gücü"

            if isCharging {
                let timeToFull = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
                if timeToFull > 0 {
                    self.timeRemainingFormatted = "\(timeToFull / 60)s \(timeToFull % 60)d (Dolmasına)"
                } else if timeToFull == 0 {
                    self.timeRemainingFormatted = "Dolu"
                } else {
                    self.timeRemainingFormatted = "Hesaplanıyor..."
                }
            } else {
                let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
                if timeToEmpty > 0 {
                    self.timeRemainingFormatted = "\(timeToEmpty / 60)s \(timeToEmpty % 60)d kaldı"
                } else if timeToEmpty == 0 {
                    self.timeRemainingFormatted = "Boş"
                } else {
                    self.timeRemainingFormatted = "Hesaplanıyor..."
                }
            }

            let healthVal = desc[kIOPSBatteryHealthKey] as? String ?? "Good"
            if healthVal == "Good" { self.health = "İyi" }
            else if healthVal == "Check Battery" { self.health = "Servis Öneriliyor" }
            else { self.health = healthVal }
        }
    }

    private func updateIOKit() {
        // Read extended info from AppleSmartBattery via IOKit registry
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return }

        self.cycleCount     = dict["CycleCount"]       as? Int ?? 0
        self.designCapacity = dict["DesignCapacity"]   as? Int ?? 0
        self.maxCapacity    = dict["MaxCapacity"]      as? Int ?? 0
        self.currentCapacity = dict["CurrentCapacity"] as? Int ?? 0

        let mv = dict["Voltage"]   as? Int ?? 0
        let ma = dict["Amperage"]  as? Int ?? 0
        self.voltage  = Double(mv) / 1000.0
        self.amperage = Double(abs(ma)) / 1000.0
        self.wattage  = self.voltage * self.amperage

        if designCapacity > 0 {
            self.healthPercent = (Double(maxCapacity) / Double(designCapacity)) * 100.0
        }
    }
}
