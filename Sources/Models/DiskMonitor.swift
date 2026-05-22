import Foundation
import IOKit

public class DiskMonitor: ObservableObject {
    @Published public var totalSpaceGB: Double = 0.0
    @Published public var freeSpaceGB: Double = 0.0
    @Published public var usedSpaceGB: Double = 0.0
    @Published public var usagePercentage: Double = 0.0
    @Published public var smartStatus: String = "UNKNOWN"
    // Throttle SMART checks to avoid frequent smartctl calls
    private var lastSmartUpdate: Date = Date(timeIntervalSince1970: 0)
    private let smartUpdateInterval: TimeInterval = 30.0
    @Published public var readSpeed: Double = 0.0
    @Published public var writeSpeed: Double = 0.0

    private var prevBytesRead: UInt64 = 0
    private var prevBytesWritten: UInt64 = 0
    private var hasPrevIO = false
    private var lastUpdateTime = Date()

    public var readSpeedFormatted: String  { DiskMonitor.formatBytes(readSpeed) }
    public var writeSpeedFormatted: String { DiskMonitor.formatBytes(writeSpeed) }

    public static func formatBytes(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1_048_576 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024.0)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576.0)
        }
    }

    public init() { update() }
    public func update() {
        updateSpace()
        updateIO()
        updateSMART()
    }

    

    private func updateSpace() {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let totalSize = attributes[.systemSize] as? UInt64,
               let freeSize  = attributes[.systemFreeSize] as? UInt64 {
                let gb = 1_073_741_824.0
                let totalBytes = Double(totalSize)
                let freeBytes  = Double(freeSize)
                self.totalSpaceGB    = totalBytes / gb
                self.freeSpaceGB     = freeBytes  / gb
                self.usedSpaceGB     = (totalBytes - freeBytes) / gb
                self.usagePercentage = totalBytes > 0 ? ((totalBytes - freeBytes) / totalBytes) * 100.0 : 0.0
            }
        } catch {}
    }

    private func updateIO() {
        var totalRead: UInt64 = 0
        var totalWritten: UInt64 = 0

        // Walk IOKit disk entries
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == KERN_SUCCESS {
            var service = IOIteratorNext(iter)
            while service != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                   let dict = props?.takeRetainedValue() as? [String: Any],
                   let stats = dict["Statistics"] as? [String: Any] {
                    if let br = stats["Bytes (Read)"]  as? UInt64 { totalRead    += br }
                    if let bw = stats["Bytes (Write)"] as? UInt64 { totalWritten += bw }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }
            IOObjectRelease(iter)
        }

        let now = Date()
        let delta = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        if hasPrevIO && delta > 0 {
            let diffRead    = totalRead    >= prevBytesRead    ? totalRead    - prevBytesRead    : 0
            let diffWritten = totalWritten >= prevBytesWritten ? totalWritten - prevBytesWritten : 0
            self.readSpeed  = Double(diffRead)    / delta
            self.writeSpeed = Double(diffWritten) / delta
        } else {
            hasPrevIO = true
        }
        prevBytesRead    = totalRead
        prevBytesWritten = totalWritten
    }

    // MARK: - SMART Status
    private func updateSMART() {
        // Run SMART check at most every `smartUpdateInterval` seconds
        let now = Date()
        if now.timeIntervalSince(lastSmartUpdate) < smartUpdateInterval { return }
        lastSmartUpdate = now
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/smartctl")
        task.arguments = ["-H", "/dev/disk0"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Look for the line containing overall health
                if let line = output.split(separator: "\n").first(where: { $0.contains("SMART overall-health self-assessment test result") }) {
                    let lower = line.lowercased()
                    if lower.contains("passed") || lower.contains("ok") {
                        DispatchQueue.main.async { self.smartStatus = "PASS" }
                    } else if lower.contains("failed") {
                        DispatchQueue.main.async { self.smartStatus = "FAIL" }
                    } else {
                        DispatchQueue.main.async { self.smartStatus = "UNKNOWN" }
                    }
                } else {
                    DispatchQueue.main.async { self.smartStatus = "UNKNOWN" }
                }
            }
        } catch {
            DispatchQueue.main.async { self.smartStatus = "UNAVAILABLE" }
        }
    }
}
