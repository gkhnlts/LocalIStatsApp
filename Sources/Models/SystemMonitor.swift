import Foundation
import Combine

public class SystemMonitor: ObservableObject {
    public let cpu = CPUMonitor()
    public let gpu = GPUMonitor()
    public let memory = MemoryMonitor()
    public let network = NetworkMonitor()
    public let wifi = WiFiMonitor()
    public let disk = DiskMonitor()
    public let battery = BatteryMonitor()
    public let sensors = SensorMonitor()
    public let processes = ProcessMonitor()
    
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    
    public init() {
        // Forward nested updates to anyone observing SystemMonitor
        cpu.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        gpu.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        memory.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // Network changes forwarding
        network.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        // Wi‑Fi changes forwarding
        wifi.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        disk.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        battery.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        sensors.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        processes.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
            
        NotificationCenter.default.addObserver(self, selector: #selector(handleIntervalChange), name: Notification.Name("UpdateIntervalChanged"), object: nil)
        
        start()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stop()
    }
    
    @objc private func handleIntervalChange() {
        start()
    }
    
    public func start() {
        stop()
        let storedInterval = UserDefaults.standard.double(forKey: "updateInterval")
        let interval = storedInterval > 0 ? storedInterval : 1.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func update() {
        cpu.update()
        gpu.update()
        memory.update()
        network.update()
        wifi.update()
        disk.update()
        battery.update()
        sensors.update()
        processes.update()
    }
}
