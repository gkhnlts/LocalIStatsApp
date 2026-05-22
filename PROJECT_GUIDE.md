# LocalIStats: macOS System Monitor Development Guide

This document defines the project structure, telemetry APIs, compilation guidelines, and task instructions for building **LocalIStats**, a native macOS menu bar system monitoring application similar to iStats X.

---

## 1. Project Directory Structure

```text
LocalIStatsApp/
├── Package.swift                 # Swift Package Manager configuration
├── PROJECT_GUIDE.md             # This file (development instructions and APIs)
├── build.sh                      # Shell script to compile, package into .app, and run
└── Sources/
    ├── main.swift                # App entry point (NSApplication bootstrapper)
    ├── App/
    │   ├── MenuBarManager.swift  # Manages NSStatusItem and NSPopover lifecycle
    │   └── PopoverController.swift # Wraps SwiftUI Popover as NSViewController
    ├── Models/
    │   ├── SystemMonitor.swift   # Base telemetry manager
    │   ├── CPUMonitor.swift      # Host CPU usage collector (sysctl/host_processor_info)
    │   ├── MemoryMonitor.swift   # Host RAM & Swap collector (host_statistics64)
    │   ├── NetworkMonitor.swift  # Network interface throughput monitor (getifaddrs)
    │   ├── BatteryMonitor.swift  # Battery health & power monitor (IOPowerSources)
    │   ├── SensorMonitor.swift   # Thermal & Fan controller (IOHIDEventSystemClient)
    │   └── DiskMonitor.swift     # Disk storage & I/O monitor
    └── Views/
        ├── PopoverView.swift     # Main popover interface (tabbed or modular view)
        ├── Components/           # Reusable SwiftUI custom gauges and charts
        │   ├── GaugeCard.swift
        │   ├── LiveChart.swift
        │   └── StatRow.swift
        └── SettingsView.swift    # Settings window / preferences panel
```

---

## 2. Compilation and Packaging without Xcode IDE

Because this codebase is developed on a machine where only Xcode Command Line Tools are present (without the full Xcode app), we compile using **Swift Package Manager (SPM)** and package the binary into a native `.app` bundle manually.

### Compilation Command
```bash
swift build -c release
```
This produces the binary at `.build/release/LocalIStats`.

### Packaging Structure
A macOS `.app` bundle is a folder structure. We package the app using `build.sh`:
```bash
mkdir -p LocalIStats.app/Contents/MacOS
mkdir -p LocalIStats.app/Contents/Resources

cp .build/release/LocalIStats LocalIStats.app/Contents/MacOS/
# Create a standard Info.plist inside LocalIStats.app/Contents/Info.plist
```

#### Info.plist Requirements
To make the application run as an accessory (menu bar icon without a Dock icon), `LSUIElement` must be set to `true`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.gokhan.LocalIStats</string>
    <key>CFBundleName</key>
    <string>LocalIStats</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>LocalIStats</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
```

---

## 3. macOS Telemetry APIs (Swift Reference)

Subsequent models implementing the models should use these macOS-native interfaces:

### A. CPU Usage
We query CPU time ticks using the host-level Mach API:
```swift
import MachO

// Use host_processor_info to get CPU ticks per core (user, system, idle, nice)
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
```
Calculate delta ticks between intervals to obtain instantaneous CPU usage.

### B. Memory Usage
We query VM statistics to compute active, inactive, wired, and compressed memory:
```swift
import Foundation

var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
var vmStats = vm_statistics64_data_t()

let result = withUnsafeMutablePointer(to: &vmStats) {
    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
    }
}

// Active = Double(vmStats.active_count) * Double(pageSize)
// Inactive = Double(vmStats.inactive_count) * Double(pageSize)
// Wired = Double(vmStats.wire_count) * Double(pageSize)
// Compressed = Double(vmStats.compressor_page_count) * Double(pageSize)
// Free = Double(vmStats.free_count) * Double(pageSize)
```

### C. Network Bandwidth
We read the raw bytes sent and received across network interfaces via `getifaddrs`:
```swift
import darwin

var ifaddr: UnsafeMutablePointer<ifaddrs>?
guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }

for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
    let name = String(cString: ptr.pointee.ifa_name)
    let flags = Int32(ptr.pointee.ifa_flags)
    let addr = ptr.pointee.ifa_addr.pointee
    
    if addr.sa_family == UInt8(AF_LINK) {
        let data = ptr.pointee.ifa_data.assumingMemoryBound(to: if_data.self)
        let bytesIn = data.pointee.ifi_ibytes
        let bytesOut = data.pointee.ifi_obytes
        // Track the change over time (delta bytes / delta time) to calculate B/s
    }
}
freeifaddrs(ifaddr)
```

### D. Battery Telemetry
Use the native `IOPowerSources` API in `IOKit`:
```swift
import IOKit.ps

let blob = IOPowerSourcesCopyProvidingPowerSourceInformation()?.takeRetainedValue()
let sources = IOPowerSourcesListCreatePowerSourceInformation(blob)?.takeRetainedValue() as? [CFTypeRef] ?? []

for source in sources {
    if let info = source as? [String: Any] {
        let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maxCapacity = info[kIOPSMaxCapacityKey] as? Int ?? 100
        let isCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        let timeLeft = info[kIOPSTimeToEmptyKey] as? Int ?? 0 // minutes
        // etc.
    }
}
```

### E. Temperatures and Fans (Apple Silicon HID Sensor Hub)
On Apple Silicon, CPU/GPU temperatures are queried dynamically by interfacing with the private `IOHIDEventSystem` API.
Since it is a private API, dynamically load `IOKit` library functions via `dlopen`/`dlsym`:

```swift
import Foundation

// Load pointers to private functions:
// - IOHIDEventSystemClientCreate
// - IOHIDEventSystemClientSetMatching
// - IOHIDServiceClientCopyEvent
// - IOHIDEventGetFloatValue

// Match pages for temperature:
// kIOHIDPage_Sensor = 0xff00
// kIOHIDType_Sensor_Temperature = 0x0005
```

---

## 4. Instructions for Subsequent AI Models

1. **Keep it Native**: Use Swift/SwiftUI and AppKit. Avoid cross-platform web wrappers (Electron/Tauri) because performance, battery usage, and native menu bar responsiveness are paramount.
2. **Handle Silicon vs. Intel**: Sensor reading might fail on older Intel Macs or Apple Silicon depending on the method. Ensure fallbacks are present.
3. **Sandbox Note**: This app is for local use. Because it queries private APIs (HID sensors for Apple Silicon temperatures), sandboxing is disabled.
4. **Follow the Phased Plan**: Implement features step-by-step using the checklist in `task.md`.
5. **No Placeholders**: Ensure all graphics (like icons or mock data) are replaced with real functional logic. Use system SF Symbols for clean, modern look.
