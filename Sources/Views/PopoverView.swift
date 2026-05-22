import SwiftUI

public struct PopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    
    @State private var selectedTab: String = "Sistem"
    @AppStorage("tempUnit") private var tempUnit: String = "C"
    @AppStorage("updateInterval") private var updateInterval: Double = 1.0
    
    public init(monitor: SystemMonitor) {
        self.monitor = monitor
    }
    
    private func formatTemp(_ celsius: Double) -> String {
        if tempUnit == "F" {
            return String(format: "%.1f °F", celsius * 9.0 / 5.0 + 32.0)
        } else {
            return String(format: "%.1f °C", celsius)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LocalIStats")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                
                Spacer()
                
                Button(action: {
                    NotificationCenter.default.post(name: Notification.Name("OpenSettings"), object: nil)
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Ayarlar")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            // Tab Selection
            HStack(spacing: 8) {
                ForEach(["Sistem", "Ağ & Disk", "Sensörler"], id: \.self) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                            .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
                .opacity(0.1)
            
            // Content List
            ScrollView {
                VStack(spacing: 12) {
                    if selectedTab == "Sistem" {
                        // CPU Card
                        let cpuVal = String(format: "%.0f%%", monitor.cpu.totalUsage)
                        GaugeCard(title: "CPU (İşlemci)", icon: "cpu", value: cpuVal, color: .blue) {
                            VStack(alignment: .leading, spacing: 6) {
                                if !monitor.cpu.cpuModel.isEmpty {
                                    Text(monitor.cpu.cpuModel)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                ProgressView(value: monitor.cpu.totalUsage / 100.0)
                                    .tint(.blue)
                                
                                HStack {
                                    Text(String(format: "Kullanıcı: %.0f%%", monitor.cpu.userUsage)).font(.caption2).foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "Sistem: %.0f%%", monitor.cpu.systemUsage)).font(.caption2).foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text(String(format: "Yük (Load): 1d: %.2f | 5d: %.2f | 15d: %.2f", monitor.cpu.loadAverage1m, monitor.cpu.loadAverage5m, monitor.cpu.loadAverage15m))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                
                                // Per-core usage bars representation
                                if !monitor.cpu.perCoreUsage.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Çekirdek Yükleri:")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        HStack(spacing: 3) {
                                            ForEach(0..<monitor.cpu.perCoreUsage.count, id: \.self) { idx in
                                                let val = monitor.cpu.perCoreUsage[idx]
                                                VStack(spacing: 1) {
                                                    GeometryReader { coreGeo in
                                                        ZStack(alignment: .bottom) {
                                                            RoundedRectangle(cornerRadius: 1)
                                                                .fill(Color.blue.opacity(0.1))
                                                            
                                                            RoundedRectangle(cornerRadius: 1)
                                                                .fill(Color.blue)
                                                                .frame(height: max(0, coreGeo.size.height * CGFloat(val / 100.0)))
                                                        }
                                                    }
                                                    .frame(height: 20)
                                                    
                                                    Text("\(idx + 1)")
                                                        .font(.system(size: 6))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                                
                                LiveChart(history: monitor.cpu.usageHistory, color: .blue, maxVal: 100.0)
                                    .frame(height: 35)
                                    .padding(.top, 4)
                             }
                        }
                        
                        // GPU Card
                        let gpuVal = String(format: "%.0f%%", monitor.gpu.utilization)
                        GaugeCard(title: "GPU (Grafik)", icon: "square.grid.3x3.fill", value: gpuVal, color: .orange) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(monitor.gpu.model)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                
                                ProgressView(value: monitor.gpu.utilization / 100.0)
                                    .tint(.orange)
                                
                                if monitor.gpu.totalVRAM > 0 {
                                    HStack {
                                        Text(String(format: "VRAM: %.1f GB / %.1f GB", monitor.gpu.usedVRAM, monitor.gpu.totalVRAM))
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                }
                                
                                LiveChart(history: monitor.gpu.usageHistory, color: .orange, maxVal: 100.0)
                                    .frame(height: 35)
                                    .padding(.top, 4)
                            }
                        }
                        
                        // Memory Card
                        let ramVal = String(format: "%.0f%%", monitor.memory.usagePercentage)
                        GaugeCard(title: "Bellek (RAM)", icon: "memorychip", value: ramVal, color: .purple) {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView(value: monitor.memory.usagePercentage / 100.0)
                                    .tint(.purple)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(String(format: "Aktif: %.1f GB", monitor.memory.activeGB)).font(.caption2).foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "Kablolu: %.1f GB", monitor.memory.wiredGB)).font(.caption2).foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text(String(format: "Sıkıştırılmış: %.1f GB", monitor.memory.compressedGB)).font(.caption2).foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "İnaktif: %.1f GB", monitor.memory.inactiveGB)).font(.caption2).foregroundColor(.secondary)
                                    }
                                    HStack {
                                        Text(String(format: "Boş: %.1f GB", monitor.memory.freeMemoryGB)).font(.caption2).foregroundColor(.secondary)
                                        Spacer()
                                        if monitor.memory.swapTotalGB > 0 {
                                            Text(String(format: "Swap: %.1f / %.1f GB", monitor.memory.swapUsedGB, monitor.memory.swapTotalGB)).font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                LiveChart(history: monitor.memory.usageHistory, color: .purple, maxVal: 100.0)
                                    .frame(height: 35)
                                    .padding(.top, 4)
                            }
                        }
                        
                        // Battery Card
                        if monitor.battery.hasBattery {
                            let batteryVal = String(format: "%.0f%%", monitor.battery.percentage)
                            let batteryIcon = monitor.battery.isCharging ? "battery.100.bolt" : "battery.100"
                            GaugeCard(title: "Pil & Güç", icon: batteryIcon, value: batteryVal, color: .green) {
                                VStack(alignment: .leading, spacing: 6) {
                                    ProgressView(value: monitor.battery.percentage / 100.0)
                                        .tint(.green)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Kaynak: \(monitor.battery.powerSource)").font(.caption2).foregroundColor(.secondary)
                                            Spacer()
                                            Text(monitor.battery.timeRemainingFormatted).font(.caption2).foregroundColor(.secondary)
                                        }
                                        HStack {
                                            Text("Pil Sağlığı: \(monitor.battery.health) (\(String(format: "%.0f%%", monitor.battery.healthPercent)))").font(.caption2).foregroundColor(.secondary)
                                            Spacer()
                                            Text("Devir (Cycle): \(monitor.battery.cycleCount)").font(.caption2).foregroundColor(.secondary)
                                        }
                                        HStack {
                                            Text(String(format: "Kapasite: %d/%d mAh", monitor.battery.currentCapacity, monitor.battery.maxCapacity)).font(.caption2).foregroundColor(.secondary)
                                            Spacer()
                                            Text(String(format: "Güç: %.2fV / %.1fW", monitor.battery.voltage, monitor.battery.wattage)).font(.caption2).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            GaugeCard(title: "Pil & Güç", icon: "bolt.fill", value: "AC Gücü", color: .green) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bu Mac modelinde pil bulunmamaktadır.").font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Top Processes Card
                        GaugeCard(title: "En Çok Kaynak Tüketenler", icon: "list.bullet.rectangle.portrait", value: "İşlemler", color: .secondary) {
                            VStack(spacing: 8) {
                                HStack(alignment: .top, spacing: 16) {
                                    // CPU processes
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("CPU İşlemleri")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.blue)
                                        
                                        if monitor.processes.topCPU.isEmpty {
                                            Text("Yükleniyor...").font(.system(size: 9)).foregroundColor(.secondary)
                                        } else {
                                            ForEach(monitor.processes.topCPU) { proc in
                                                HStack {
                                                    Text(proc.name)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(proc.formattedValue)
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Divider()
                                    
                                    // Memory processes
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("RAM İşlemleri")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.purple)
                                        
                                        if monitor.processes.topMemory.isEmpty {
                                            Text("Yükleniyor...").font(.system(size: 9)).foregroundColor(.secondary)
                                        } else {
                                            ForEach(monitor.processes.topMemory) { proc in
                                                HStack {
                                                    Text(proc.name)
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(proc.formattedValue)
                                                        .font(.system(size: 9, weight: .semibold))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    } else if selectedTab == "Ağ & Disk" {
                        // Network Card
                        let netVal = monitor.network.downloadSpeedFormatted
                        GaugeCard(title: "Ağ Arayüzü (\(monitor.network.activeInterface))", icon: "network", value: netVal, color: .teal) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: "arrow.down")
                                        .foregroundColor(.teal)
                                    Text("İn: \(monitor.network.downloadSpeedFormatted)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "arrow.up")
                                        .foregroundColor(.blue)
                                    Text("Out: \(monitor.network.uploadSpeedFormatted)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Yerel IP: \(monitor.network.localIP)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Genel IP: \(monitor.network.publicIP)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Toplam Gelen: \(monitor.network.totalReceivedFormatted)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Toplam Giden: \(monitor.network.totalSentFormatted)")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                
                                let maxNetVal = max(50_000.0, monitor.network.downloadHistory.max() ?? 50_000.0)
                                LiveChart(history: monitor.network.downloadHistory, color: .teal, maxVal: maxNetVal)
                                    .frame(height: 35)
                                    .padding(.top, 4)
                            }
                        }
                        
                        // Disk Card
                        let diskVal = String(format: "%.0f%%", monitor.disk.usagePercentage)
                        GaugeCard(title: "Depolama (Macintosh HD)", icon: "internaldrive", value: diskVal, color: .orange) {
                            VStack(alignment: .leading, spacing: 6) {
                                ProgressView(value: monitor.disk.usagePercentage / 100.0)
                                    .tint(.orange)
                                
                                HStack {
                                    Text(String(format: "Kullanılan: %.1f GB", monitor.disk.usedSpaceGB)).font(.caption2).foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "Toplam: %.1f GB", monitor.disk.totalSpaceGB)).font(.caption2).foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Text("Disk Okuma: \(monitor.disk.readSpeedFormatted)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                        Text("SMART: \(monitor.disk.smartStatus)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Disk Yazma: \(monitor.disk.writeSpeedFormatted)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 2)
                            }
                        }

                        // Wi‑Fi Card
                        let wifiVal = "\(monitor.wifi.ssid) (\(monitor.wifi.rssi) dBm)"
                        GaugeCard(title: "Wi‑Fi (\(monitor.wifi.interfaceName))", icon: "wifi", value: wifiVal, color: .blue) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("SSID: \(monitor.wifi.ssid)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("RSSI: \(monitor.wifi.rssi) dBm")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // Sensors Card & Full List
                        VStack(alignment: .leading, spacing: 12) {
                            let tempVal = formatTemp(monitor.sensors.cpuTemp)
                            GaugeCard(title: "Ortalama Sıcaklıklar", icon: "thermometer.medium", value: tempVal, color: .red) {
                                VStack(spacing: 8) {
                                    StatRow(name: "CPU Sıcaklığı", value: formatTemp(monitor.sensors.cpuTemp), icon: "cpu", iconColor: .red)
                                    StatRow(name: "GPU Sıcaklığı", value: formatTemp(monitor.sensors.gpuTemp), icon: "square.grid.3x3.fill", iconColor: .orange)
                                    StatRow(name: "Pil Sıcaklığı", value: formatTemp(monitor.sensors.batteryTemp), icon: "battery.100", iconColor: .green)
                                    
                                    let fanText = monitor.sensors.fanSpeedRPM > 0 ? String(format: "%.0f RPM", monitor.sensors.fanSpeedRPM) : "Hareketsiz / Fansız"
                                    StatRow(name: "Fan Hızı", value: fanText, icon: "wind", iconColor: .blue)
                                }
                            }
                            
                            if !monitor.sensors.sensorList.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Detaylı Sensör Listesi (\(monitor.sensors.sensorList.count))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                    
                                    VStack(spacing: 4) {
                                        ForEach(monitor.sensors.sensorList) { sensor in
                                            let displayVal: String = {
                                                if tempUnit == "F" && sensor.value.contains("°C") {
                                                    let cleaned = sensor.value.replacingOccurrences(of: " °C", with: "").replacingOccurrences(of: "°C", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                                                    if let celVal = Double(cleaned) {
                                                        return String(format: "%.1f °F", celVal * 9.0 / 5.0 + 32.0)
                                                    }
                                                }
                                                return sensor.value
                                            }()
                                            
                                            let catIcon: String = {
                                                switch sensor.category {
                                                case "CPU": return "cpu"
                                                case "GPU": return "square.grid.3x3.fill"
                                                case "Fan": return "wind"
                                                default: return "thermometer"
                                                }
                                            }()
                                            
                                            let catColor: Color = {
                                                switch sensor.category {
                                                case "CPU": return .red
                                                case "GPU": return .orange
                                                case "Fan": return .blue
                                                default: return .secondary
                                                }
                                            }()
                                            
                                            StatRow(name: sensor.name, value: displayVal, icon: catIcon, iconColor: catColor)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.primary.opacity(0.02))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.04), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .frame(height: 380)
            
            Divider()
                .opacity(0.3)
            
            // Footer
            HStack {
                Text(String(format: "Güncellenme: %.1fs aralıklarla", updateInterval))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                
                Button("Gizle") {
                    NotificationCenter.default.post(name: Notification.Name("ClosePopover"), object: nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.borderless)
                
                Text("|")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .opacity(0.4)
                
                Button("Çıkış") {
                    NSApp.terminate(nil)
                }
                .font(.system(size: 10))
                .foregroundColor(.red)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.05))
        }
        .frame(width: 320)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
