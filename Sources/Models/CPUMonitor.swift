import Foundation
import MachO

public class CPUMonitor: ObservableObject {
    @Published public var totalUsage: Double = 0.0
    @Published public var userUsage: Double = 0.0
    @Published public var systemUsage: Double = 0.0
    @Published public var usageHistory: [Double] = []
    @Published public var perCoreUsage: [Double] = []
    @Published public var loadAverage1m: Double = 0.0
    @Published public var loadAverage5m: Double = 0.0
    @Published public var loadAverage15m: Double = 0.0
    @Published public var cpuModel: String = ""
    @Published public var coreCount: Int = 0
    @Published public var cpuClockMHz: Double = 0.0
    @Published public var maxCPUClockMHz: Double = 3200.0

    private var prevCpuInfo = host_cpu_load_info()
    private var hasPrevInfo = false

    // Per-core tracking
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorCount: mach_msg_type_number_t = 0
    private var hasPrevCoreInfo = false

    public init() {
        usageHistory = Array(repeating: 0.0, count: 30)
        loadCPUModel()
        update()
    }

    deinit {
        if let prev = prevProcessorInfo {
            let size = MemoryLayout<integer_t>.stride * Int(prevProcessorCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(size))
        }
    }

    private func loadCPUModel() {
        // Physical core count
        var count: Int32 = 0
        var countSize = MemoryLayout<Int32>.size
        sysctlbyname("hw.physicalcpu", &count, &countSize, nil, 0)
        self.coreCount = Int(count)

        // CPU brand string
        var brandBytes = [CChar](repeating: 0, count: 256)
        var brandSize = brandBytes.count
        if sysctlbyname("machdep.cpu.brand_string", &brandBytes, &brandSize, nil, 0) == 0 {
            self.cpuModel = String(cString: brandBytes)
        } else {
            // Fallback for Apple Silicon
            var modelBytes = [CChar](repeating: 0, count: 256)
            var modelSize = modelBytes.count
            sysctlbyname("hw.model", &modelBytes, &modelSize, nil, 0)
            self.cpuModel = String(cString: modelBytes)
        }
        
        let modelLower = self.cpuModel.lowercased()
        if modelLower.contains("m4") {
            self.maxCPUClockMHz = 4400.0
        } else if modelLower.contains("m3") {
            self.maxCPUClockMHz = 4050.0
        } else if modelLower.contains("m2") {
            self.maxCPUClockMHz = 3490.0
        } else if modelLower.contains("m1") {
            self.maxCPUClockMHz = 3200.0
        } else {
            self.maxCPUClockMHz = 3500.0
        }
    }

    public func update() {
        updateTotalUsage()
        updatePerCoreUsage()
        updateLoadAverages()
        
        let usageFraction = self.totalUsage / 100.0
        let baseMHz = self.maxCPUClockMHz * 0.3
        self.cpuClockMHz = baseMHz + (self.maxCPUClockMHz - baseMHz) * usageFraction
    }

    private func updateTotalUsage() {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var cpuInfo = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        if hasPrevInfo {
            let userDiff   = Double(cpuInfo.cpu_ticks.0 - prevCpuInfo.cpu_ticks.0)
            let sysDiff    = Double(cpuInfo.cpu_ticks.1 - prevCpuInfo.cpu_ticks.1)
            let idleDiff   = Double(cpuInfo.cpu_ticks.2 - prevCpuInfo.cpu_ticks.2)
            let niceDiff   = Double(cpuInfo.cpu_ticks.3 - prevCpuInfo.cpu_ticks.3)
            let totalTicks = userDiff + sysDiff + idleDiff + niceDiff

            if totalTicks > 0 {
                self.userUsage   = (userDiff / totalTicks) * 100.0
                self.systemUsage = (sysDiff  / totalTicks) * 100.0
                self.totalUsage  = self.userUsage + self.systemUsage + (niceDiff / totalTicks) * 100.0
            }
        } else {
            hasPrevInfo = true
        }
        prevCpuInfo = cpuInfo

        self.usageHistory.append(self.totalUsage)
        if self.usageHistory.count > 30 { self.usageHistory.removeFirst() }
    }

    private func updatePerCoreUsage() {
        var processorInfo: processor_info_array_t?
        var processorMsgCount: mach_msg_type_number_t = 0
        var processorCount: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else { return }

        var coreUsages: [Double] = []
        let stride = Int(CPU_STATE_MAX)

        for i in 0..<Int(processorCount) {
            let base = i * stride
            if hasPrevCoreInfo, let prev = prevProcessorInfo {
                let userDiff = Double(info[base + Int(CPU_STATE_USER)]   - prev[base + Int(CPU_STATE_USER)])
                let sysDiff  = Double(info[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)])
                let idleDiff = Double(info[base + Int(CPU_STATE_IDLE)]   - prev[base + Int(CPU_STATE_IDLE)])
                let niceDiff = Double(info[base + Int(CPU_STATE_NICE)]   - prev[base + Int(CPU_STATE_NICE)])
                let total = userDiff + sysDiff + idleDiff + niceDiff
                let used  = userDiff + sysDiff + niceDiff
                coreUsages.append(total > 0 ? (used / total) * 100.0 : 0.0)
            }
        }

        if !coreUsages.isEmpty { self.perCoreUsage = coreUsages }

        // Free previous info
        if let prev = prevProcessorInfo {
            let size = MemoryLayout<integer_t>.stride * Int(prevProcessorCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(size))
        }
        prevProcessorInfo = info
        prevProcessorCount = processorMsgCount
        hasPrevCoreInfo = true
    }

    private func updateLoadAverages() {
        var avg = [Double](repeating: 0.0, count: 3)
        if getloadavg(&avg, 3) == 3 {
            self.loadAverage1m  = avg[0]
            self.loadAverage5m  = avg[1]
            self.loadAverage15m = avg[2]
        }
    }
}
