import Foundation
import Darwin

public class NetworkMonitor: ObservableObject {
    @Published public var downloadSpeed: Double = 0.0
    @Published public var uploadSpeed: Double = 0.0
    @Published public var downloadHistory: [Double] = []
    @Published public var uploadHistory: [Double] = []
    @Published public var activeInterface: String = ""
    @Published public var totalBytesReceived: UInt64 = 0
    @Published public var totalBytesSent: UInt64 = 0
    @Published public var localIP: String = "127.0.0.1"
    @Published public var publicIP: String = "Yükleniyor..."

    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var hasPrevInfo = false
    private var lastUpdateTime = Date()
    private var publicIPCounter = 0

    public var downloadSpeedFormatted: String { NetworkMonitor.formatSpeed(downloadSpeed) }
    public var uploadSpeedFormatted:   String { NetworkMonitor.formatSpeed(uploadSpeed) }
    public var totalReceivedFormatted: String { NetworkMonitor.formatTotal(totalBytesReceived) }
    public var totalSentFormatted:     String { NetworkMonitor.formatTotal(totalBytesSent) }

    public static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond < 1024 {
            return String(format: "%.0f B/s", bytesPerSecond)
        } else if bytesPerSecond < 1_048_576 {
            return String(format: "%.1f KB/s", bytesPerSecond / 1024.0)
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576.0)
        }
    }

    public static func formatTotal(_ bytes: UInt64) -> String {
        let d = Double(bytes)
        if d < 1_048_576 {
            return String(format: "%.1f KB", d / 1024.0)
        } else if d < 1_073_741_824 {
            return String(format: "%.1f MB", d / 1_048_576.0)
        } else {
            return String(format: "%.2f GB", d / 1_073_741_824.0)
        }
    }

    public init() {
        downloadHistory = Array(repeating: 0.0, count: 30)
        uploadHistory   = Array(repeating: 0.0, count: 30)
        update()
        fetchPublicIP()
    }

    public func fetchPublicIP() {
        guard let url = URL(string: "https://api.ipify.org") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let data = data, let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                DispatchQueue.main.async {
                    self?.publicIP = ip
                }
            }
        }
        .resume()
    }

    public func update() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalBytesIn:  UInt64 = 0
        var totalBytesOut: UInt64 = 0
        var bestInterface  = ""
        var bestBytes: UInt64 = 0
        var detectedLocalIP = "127.0.0.1"

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let name  = String(cString: ptr.pointee.ifa_name)
            if name == "lo0" { continue }

            let addr = ptr.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_LINK) {
                let data = ptr.pointee.ifa_data.assumingMemoryBound(to: if_data.self)
                let ibytes = UInt64(data.pointee.ifi_ibytes)
                let obytes = UInt64(data.pointee.ifi_obytes)
                totalBytesIn  += ibytes
                totalBytesOut += obytes

                if ibytes + obytes > bestBytes {
                    bestBytes = ibytes + obytes
                    bestInterface = name
                }
            } else if addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if !ip.hasPrefix("127.") {
                        detectedLocalIP = ip
                    }
                }
            }
        }

        self.totalBytesReceived = totalBytesIn
        self.totalBytesSent     = totalBytesOut
        self.activeInterface    = bestInterface
        self.localIP            = detectedLocalIP

        let now = Date()
        let timeDelta = now.timeIntervalSince(lastUpdateTime)
        lastUpdateTime = now

        if hasPrevInfo && timeDelta > 0 {
            let diffIn  = totalBytesIn  >= prevBytesIn  ? totalBytesIn  - prevBytesIn  : 0
            let diffOut = totalBytesOut >= prevBytesOut ? totalBytesOut - prevBytesOut : 0
            self.downloadSpeed = Double(diffIn)  / timeDelta
            self.uploadSpeed   = Double(diffOut) / timeDelta
        } else {
            hasPrevInfo = true
        }
        prevBytesIn  = totalBytesIn
        prevBytesOut = totalBytesOut

        downloadHistory.append(downloadSpeed)
        if downloadHistory.count > 30 { downloadHistory.removeFirst() }
        uploadHistory.append(uploadSpeed)
        if uploadHistory.count > 30 { uploadHistory.removeFirst() }

        publicIPCounter += 1
        if publicIPCounter >= 60 || self.publicIP == "Yükleniyor..." {
            publicIPCounter = 0
            fetchPublicIP()
        }
    }
}
