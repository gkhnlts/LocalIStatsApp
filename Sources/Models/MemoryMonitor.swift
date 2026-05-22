import Foundation
import MachO

public class MemoryMonitor: ObservableObject {
    @Published public var totalMemoryGB: Double = 0.0
    @Published public var usedMemoryGB: Double = 0.0
    @Published public var freeMemoryGB: Double = 0.0
    @Published public var activeGB: Double = 0.0
    @Published public var inactiveGB: Double = 0.0
    @Published public var wiredGB: Double = 0.0
    @Published public var compressedGB: Double = 0.0
    @Published public var swapUsedGB: Double = 0.0
    @Published public var swapTotalGB: Double = 0.0
    @Published public var usagePercentage: Double = 0.0
    @Published public var usageHistory: [Double] = []

    private var totalBytes: UInt64 = 0

    public init() {
        usageHistory = Array(repeating: 0.0, count: 30)
        var size = MemoryLayout<UInt64>.size
        let result = sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)
        totalMemoryGB = result == 0 ? Double(totalBytes) / 1_073_741_824.0 : 8.0
        update()
    }

    public func update() {
        updateVMStats()
        updateSwap()
    }

    private func updateVMStats() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64_data_t()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        let pageSize = Double(vm_kernel_page_size)
        let active     = Double(vmStats.active_count)     * pageSize
        let inactive   = Double(vmStats.inactive_count)   * pageSize
        let wired      = Double(vmStats.wire_count)       * pageSize
        let compressed = Double(vmStats.compressor_page_count) * pageSize

        let gb = 1_073_741_824.0
        self.activeGB     = active     / gb
        self.inactiveGB   = inactive   / gb
        self.wiredGB      = wired      / gb
        self.compressedGB = compressed / gb
        self.usedMemoryGB = (active + wired + compressed) / gb
        self.freeMemoryGB = max(0.0, totalMemoryGB - usedMemoryGB)

        if totalMemoryGB > 0 {
            self.usagePercentage = (usedMemoryGB / totalMemoryGB) * 100.0
        }

        self.usageHistory.append(self.usagePercentage)
        if self.usageHistory.count > 30 { self.usageHistory.removeFirst() }
    }

    private func updateSwap() {
        var swapInfo = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swapInfo, &size, nil, 0) == 0 {
            let gb = 1_073_741_824.0
            self.swapTotalGB = Double(swapInfo.xsu_total) / gb
            self.swapUsedGB  = Double(swapInfo.xsu_used)  / gb
        }
    }
}
