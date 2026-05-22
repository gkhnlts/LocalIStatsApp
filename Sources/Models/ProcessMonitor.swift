import Foundation

public struct ProcessItem: Identifiable, Equatable {
    public var id: Int { pid }
    public var pid: Int
    public var name: String
    public var usageValue: Double
    public var formattedValue: String
}

public class ProcessMonitor: ObservableObject {
    @Published public var topCPU: [ProcessItem] = []
    @Published public var topMemory: [ProcessItem] = []
    
    private let queue = DispatchQueue(label: "com.gokhan.LocalIStats.processes", qos: .background)
    private var timer: Timer?
    private let updateInterval: TimeInterval = 5.0
    
    public init() {
        start()
    }
    
    deinit {
        stop()
    }
    
    private func start() {
        // Start the periodic update timer on the main run loop in common mode
        timer = Timer(timeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer!, forMode: .common)
        // Perform an immediate update so UI shows data without waiting for the first interval
        update()
    }
    
    private func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    public func update() {
        queue.async {
            let cpu = self.runPS(args: ["-A", "-o", "%cpu,pid,comm"])
            let mem = self.runPS(args: ["-A", "-o", "%mem,pid,comm"])
            
            DispatchQueue.main.async {
                self.topCPU = cpu.sorted { $0.usageValue > $1.usageValue }.prefix(5).map { $0 }
                self.topMemory = mem.sorted { $0.usageValue > $1.usageValue }.prefix(5).map { $0 }
            }
        }
    }
    
    private func runPS(args: [String]) -> [ProcessItem] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = args
        // Ensure consistent numeric formatting (dot as decimal separator)
        task.environment = ["LC_ALL": "C"]
        // Ensure consistent number formatting regardless of user locale
        task.environment = ["LC_ALL": "C"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return parsePSOutput(output)
            }
        } catch {
            print("Failed to run ps command: \(error)")
        }
        return []
    }
    
    private func parsePSOutput(_ output: String) -> [ProcessItem] {
        var items: [ProcessItem] = []
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if components.count >= 3,
               let val = Double(components[0].replacingOccurrences(of: ",", with: ".")),
               let pid = Int(components[1]) {
                let name = components.dropFirst(2).joined(separator: " ")
                let formatted = String(format: "%.1f%%", val)
                items.append(ProcessItem(pid: pid, name: name, usageValue: val, formattedValue: formatted))
                // Removed early break to allow collection of all processes; top 5 will be selected later
            }
        }
        return items
    }
}
