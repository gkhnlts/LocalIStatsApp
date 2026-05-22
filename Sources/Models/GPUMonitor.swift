import Foundation
import IOKit

public class GPUMonitor: ObservableObject {
    @Published public var utilization: Double = 0.0
    @Published public var model: String = ""
    @Published public var freeVRAM: Double = 0.0
    @Published public var usedVRAM: Double = 0.0
    @Published public var totalVRAM: Double = 0.0
    @Published public var usageHistory: [Double] = []
    @Published public var gpuClockMHz: Double = 0.0
    @Published public var maxGPUClockMHz: Double = 1398.0

    public init() {
        usageHistory = Array(repeating: 0.0, count: 30)
        detectGPUModel()
        update()
    }

    private func detectGPUModel() {
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOGraphicsDevice")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
            var service = IOIteratorNext(iter)
            while service != 0 {
                if let nameBytes = IORegistryEntryCreateCFProperty(service, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data {
                    let modelName = String(decoding: nameBytes, as: UTF8.self).trimmingCharacters(in: .controlCharacters)
                    if !modelName.isEmpty {
                        self.model = modelName
                        IOObjectRelease(service)
                        break
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        
        if self.model.isEmpty {
            self.model = "Apple GPU"
        }
        
        let modelLower = self.model.lowercased()
        if modelLower.contains("m4") {
            self.maxGPUClockMHz = 1600.0
        } else if modelLower.contains("m3") {
            self.maxGPUClockMHz = 1500.0
        } else if modelLower.contains("m2") {
            self.maxGPUClockMHz = 1398.0
        } else {
            self.maxGPUClockMHz = 1278.0
        }
    }

    public func update() {
        var gpuUsage: Double = 0.0
        var foundVram = false
        
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
            var service = IOIteratorNext(iter)
            while service != 0 {
                var properties: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = properties?.takeRetainedValue() as? [String: Any],
                   let stats = dict["PerformanceStatistics"] as? [String: Any] {
                    
                    if let util = stats["Device Utilization %"] as? Double {
                        gpuUsage = max(gpuUsage, util)
                    } else if let util = stats["Device Utilization %"] as? Int {
                        gpuUsage = max(gpuUsage, Double(util))
                    } else if let util = stats["Device Utilization % at cur p-state"] as? Double {
                        gpuUsage = max(gpuUsage, util)
                    } else if let util = stats["Device Utilization % at cur p-state"] as? Int {
                        gpuUsage = max(gpuUsage, Double(util))
                    } else if let util = stats["utilization"] as? Double {
                        gpuUsage = max(gpuUsage, util)
                    }
                    
                    if let freeBytes = stats["vramFreeBytes"] as? UInt64 {
                        self.freeVRAM = Double(freeBytes) / 1_073_741_824.0
                        foundVram = true
                    }
                    if let usedBytes = stats["vramUsedBytes"] as? UInt64 {
                        self.usedVRAM = Double(usedBytes) / 1_073_741_824.0
                        foundVram = true
                    }
                    if foundVram {
                        self.totalVRAM = self.freeVRAM + self.usedVRAM
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }
        
        self.utilization = min(max(gpuUsage, 0.0), 100.0)
        
        if !foundVram {
            var ramSize: UInt64 = 0
            var ramLen = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &ramSize, &ramLen, nil, 0)
            let systemGB = Double(ramSize) / 1_073_741_824.0
            
            self.totalVRAM = systemGB * 0.5
            self.usedVRAM = 0.12 + (self.totalVRAM - 0.12) * (self.utilization / 100.0)
            self.freeVRAM = self.totalVRAM - self.usedVRAM
        }
        
        let baseGPU = self.maxGPUClockMHz * 0.1
        self.gpuClockMHz = baseGPU + (self.maxGPUClockMHz - baseGPU) * (self.utilization / 100.0)
        
        self.usageHistory.append(self.utilization)
        if self.usageHistory.count > 30 {
            self.usageHistory.removeFirst()
        }
    }
}
