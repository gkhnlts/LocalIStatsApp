import Foundation
import IOKit

// C structures and definitions for SMC communication
struct SMCKeyData_version {
    var major: UInt8 = 0
    var minor: UInt8 = 0
    var build: UInt8 = 0
    var reserved: UInt8 = 0
    var release: UInt16 = 0
}

struct SMCKeyData_limits {
    var maxSpeed: UInt16 = 0
    var minSpeed: UInt16 = 0
    var limitSpeed: UInt16 = 0
}

struct SMCKeyData_keyInfo {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

struct SMCKeyData {
    var key: UInt32 = 0
    var vers = SMCKeyData_version()
    var limits = SMCKeyData_limits()
    var keyInfo = SMCKeyData_keyInfo()
    var result: UInt8 = 0
    var val: UInt8 = 0
    var data: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

public class SensorMonitor: ObservableObject {
    @Published public var cpuTemp: Double = 0.0
    @Published public var gpuTemp: Double = 0.0
    @Published public var batteryTemp: Double = 0.0
    @Published public var fanSpeedRPM: Double = 0.0
    @Published public var sensorList: [SensorItem] = []
    @Published public var cpuTempHistory: [Double] = []
    @Published public var gpuTempHistory: [Double] = []
    
    // IOHID Dynamic Function Pointer Types
    private typealias IOHIDEventSystemClientRef = UnsafeMutableRawPointer
    private typealias IOHIDServiceClientRef = UnsafeMutableRawPointer
    private typealias IOHIDEventRef = UnsafeMutableRawPointer
    
    private var iohidClient: IOHIDEventSystemClientRef?
    
    // SMC Connection
    private var smcConnection: io_connect_t = 0
    
    public struct SensorItem: Identifiable, Equatable {
        public var id: String { name }
        public var name: String
        public var value: String
        public var category: String // "CPU", "GPU", "Sistem", "Fan"
    }
    
    public init() {
        self.cpuTempHistory = Array(repeating: 35.0, count: 30)
        self.gpuTempHistory = Array(repeating: 35.0, count: 30)
        setupIOHID()
        setupSMC()
        update()
    }
    
    deinit {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
        }
    }
    
    // Setup Apple Silicon Temperature Monitor via private IOHID API
    private func setupIOHID() {
        let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_NOW)
        guard iokit != nil else { return }
        
        let clientCreate = dlsym(iokit, "IOHIDEventSystemClientCreate")
        if let clientCreate = clientCreate {
            let IOHIDEventSystemClientCreate = unsafeBitCast(
                clientCreate,
                to: (@convention(c) (CFAllocator?) -> IOHIDEventSystemClientRef?).self
            )
            self.iohidClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault)
        }
    }
    
    // Setup Fan Monitor via AppleSMC
    private func setupSMC() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service == 0 {
            return
        }
        defer { IOObjectRelease(service) }
        
        let result = IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        if result != KERN_SUCCESS {
            smcConnection = 0
        }
    }
    
    public func update() {
        updateTemperatures()
        updateFans()
    }
    
    private func updateTemperatures() {
        guard let client = iohidClient else { return }
        
        let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/Versions/A/IOKit", RTLD_NOW)
        guard let iokit = iokit else { return }
        
        guard let copyServicesSym = dlsym(iokit, "IOHIDEventSystemClientCopyServices"),
              let copyEventSym = dlsym(iokit, "IOHIDServiceClientCopyEvent"),
              let getFloatSym = dlsym(iokit, "IOHIDEventGetFloatValue"),
              let copyPropSym = dlsym(iokit, "IOHIDServiceClientCopyProperty") else {
            return
        }
        
        let IOHIDEventSystemClientCopyServices = unsafeBitCast(
            copyServicesSym,
            to: (@convention(c) (IOHIDEventSystemClientRef) -> CFArray?).self
        )
        
        let IOHIDServiceClientCopyEvent = unsafeBitCast(
            copyEventSym,
            to: (@convention(c) (IOHIDServiceClientRef, UInt32, UInt32, CFOptionFlags) -> IOHIDEventRef?).self
        )
        
        let IOHIDEventGetFloatValue = unsafeBitCast(
            getFloatSym,
            to: (@convention(c) (IOHIDEventRef, UInt32) -> Double).self
        )
        
        let IOHIDServiceClientCopyProperty = unsafeBitCast(
            copyPropSym,
            to: (@convention(c) (IOHIDServiceClientRef, CFString) -> CFTypeRef?).self
        )
        
        guard let servicesCF = IOHIDEventSystemClientCopyServices(client) else {
            return
        }
        
        let services = servicesCF as NSArray
        var temps: [String: Double] = [:]
        
        for i in 0..<services.count {
            let serviceObj = services[i] as AnyObject
            let service = UnsafeMutableRawPointer(Unmanaged.passUnretained(serviceObj).toOpaque())
            
            if let product = IOHIDServiceClientCopyProperty(service, "Product" as CFString) as? String {
                // We target temperature events
                // 15 = kIOHIDEventTypeTemperature
                if let event = IOHIDServiceClientCopyEvent(service, 15, 0, 0) {
                    // 15 << 16 = 983040 -> Temperature value field index (kIOHIDEventFieldTemperatureLevel)
                    let tempVal = IOHIDEventGetFloatValue(event, 983040)
                    
                    if tempVal > 0.0 && tempVal < 150.0 {
                        temps[product] = tempVal
                    }
                }
            }
        }
        
        // Match specific Apple Silicon thermal sensors
        // Tp09 / Tp05 / Tp1b: Performance / Efficiency core sensors
        // Tg05 / Tg1b: GPU sensors
        // Ts05: System/SoC temp
        // PMU tdie: Power Management temperature
        var cpuSamples: [Double] = []
        var gpuSamples: [Double] = []
        var batterySamples: [Double] = []
        var newList: [SensorItem] = []
        
        for (name, val) in temps {
            let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Core mapping classifications
            if cleanName.hasPrefix("Tp") || cleanName.contains("CPU") || cleanName.contains("pACC") || cleanName.contains("eACC") {
                cpuSamples.append(val)
                newList.append(SensorItem(name: "İşlemci Çekirdeği (\(cleanName))", value: String(format: "%.1f °C", val), category: "CPU"))
            } else if cleanName.hasPrefix("Tg") || cleanName.contains("GPU") || cleanName.contains("gpu") {
                gpuSamples.append(val)
                newList.append(SensorItem(name: "Grafik Birimi (\(cleanName))", value: String(format: "%.1f °C", val), category: "GPU"))
            } else if cleanName.hasPrefix("Tb") || cleanName.contains("Battery") || cleanName.contains("battery") {
                batterySamples.append(val)
            } else {
                newList.append(SensorItem(name: cleanName, value: String(format: "%.1f °C", val), category: "Sistem"))
            }
        }
        
        // Update general averages
        if !cpuSamples.isEmpty {
            self.cpuTemp = cpuSamples.reduce(0.0, +) / Double(cpuSamples.count)
        } else if let socTemp = temps["Ts05"] { // SoC sensor fallback
            self.cpuTemp = socTemp
        } else {
            self.cpuTemp = temps.values.first ?? 40.0 // Default fallback
        }
        
        if !gpuSamples.isEmpty {
            self.gpuTemp = gpuSamples.reduce(0.0, +) / Double(gpuSamples.count)
        } else {
            self.gpuTemp = self.cpuTemp - 3.0 // estimation fallback
        }
        
        if !batterySamples.isEmpty {
            self.batteryTemp = batterySamples.reduce(0.0, +) / Double(batterySamples.count)
        } else {
            self.batteryTemp = 32.0 // default safe room temp
        }
        
        // Sorting items to make it clean
        self.sensorList = newList.sorted { $0.name < $1.name }
    }
    
    // Reads actual physical Fan speeds via AppleSMC connection
    private func updateFans() {
        guard smcConnection != 0 else {
            self.fanSpeedRPM = 0.0
            return
        }
        
        var fansFound = false
        // Remove previous fan entries to avoid duplicates
        self.sensorList = self.sensorList.filter { $0.category != "Fan" }
        
        for i in 0..<4 {
            let actualSpeedVal = readSMCKey("F\(i)Ac")
            if actualSpeedVal > 0 {
                fansFound = true
                self.sensorList.append(SensorItem(
                    name: "Fan \(i) Hızı",
                    value: String(format: "%.0f RPM", actualSpeedVal),
                    category: "Fan"
                ))
            }
        }
        
        if !fansFound {
            self.fanSpeedRPM = 0.0
        } else {
            self.fanSpeedRPM = readSMCKey("F0Ac")
        }
    }
    
    // Core SMC Reading routine
    private func readSMCKey(_ keyStr: String) -> Double {
        guard smcConnection != 0 else { return 0 }
        
        var keyVal = UInt32(0)
        let chars = Array(keyStr.utf8)
        guard chars.count == 4 else { return 0 }
        
        // Convert 4-character string to 32-bit integer key
        keyVal = (UInt32(chars[0]) << 24) |
                 (UInt32(chars[1]) << 16) |
                 (UInt32(chars[2]) << 8)  |
                  UInt32(chars[3])
                  
        var inputStructure = SMCKeyData()
        var outputStructure = SMCKeyData()
        
        inputStructure.key = keyVal
        inputStructure.val = 5 // SMC_CMD_READ_BYTES
        
        let inputStructSize = MemoryLayout<SMCKeyData>.size
        var outputStructSize = MemoryLayout<SMCKeyData>.size
        
        // Call AppleSMC method 2 (SMC_CMD_KEY_INFO) to retrieve key information
        inputStructure.val = 9 // SMC_CMD_KEY_INFO
        var result = IOConnectCallStructMethod(
            smcConnection,
            2, // Method Index for struct
            &inputStructure,
            inputStructSize,
            &outputStructure,
            &outputStructSize
        )
        
        guard result == kIOReturnSuccess else { return 0 }
        
        let size = outputStructure.keyInfo.dataSize
        let dataType = outputStructure.keyInfo.dataType
        
        // Prepare read command
        inputStructure.key = keyVal
        inputStructure.keyInfo.dataSize = size
        inputStructure.val = 5 // SMC_CMD_READ_BYTES
        
        result = IOConnectCallStructMethod(
            smcConnection,
            2,
            &inputStructure,
            inputStructSize,
            &outputStructure,
            &outputStructSize
        )
        
        guard result == kIOReturnSuccess && outputStructure.result == 0 else { return 0 }
        
        // Parse fan speed which uses 'fpe2' (fixed point 14.2) data type
        // 'fpe2' stands for Float Point Encoded: 2 bits for decimal, 14 bits for integer
        if dataType == 1718387058 { // 'fpe2' in ASCII integer representation
            let byte0 = UInt32(outputStructure.data.0)
            let byte1 = UInt32(outputStructure.data.1)
            let rpm = Double((byte0 << 6) | (byte1 >> 2)) + Double(byte1 & 3) / 4.0
            return rpm
        }
        
        return 0
    }
}
