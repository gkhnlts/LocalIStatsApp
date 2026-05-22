import Foundation
import CoreWLAN

public class WiFiMonitor: ObservableObject {
    @Published public var ssid: String = ""
    @Published public var rssi: Int = 0
    @Published public var interfaceName: String = ""
    
    private var timer: Timer?
    
    public init() {
        start()
    }
    
    deinit {
        stop()
    }
    
    private func start() {
        stop()
        // Update every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        // Immediate update
        update()
    }
    
    private func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func update() {
        guard let interface = CWWiFiClient.shared().interface() else {
            DispatchQueue.main.async {
                self.ssid = ""
                self.rssi = 0
                self.interfaceName = ""
            }
            return
        }
        let currentSSID = interface.ssid() ?? ""
        let currentRSSI = interface.rssiValue()
        let name = interface.interfaceName ?? ""
        DispatchQueue.main.async {
            self.ssid = currentSSID
            self.rssi = currentRSSI
            self.interfaceName = name
        }
    }
}
