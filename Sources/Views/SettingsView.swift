import SwiftUI

public struct SettingsView: View {
    @AppStorage("updateInterval") private var updateInterval: Double = 1.0
    @AppStorage("tempUnit") private var tempUnit: String = "C"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("menuBarStyle") private var menuBarStyle: String = "icon"
    
    public init() {}
    
    public var body: some View {
        TabView {
            // General Settings Tab
            Form {
                Section(header: Text("Uygulama Ayarları").font(.headline)) {
                    Toggle("Girişte Otomatik Başlat", isOn: $launchAtLogin)
                        .toggleStyle(.checkbox)
                        .onChange(of: launchAtLogin) { oldValue, newValue in
                            toggleLaunchAtLogin(newValue)
                        }
                    
                    Picker("Güncelleme Sıklığı:", selection: $updateInterval) {
                        Text("0.5 Saniye").tag(0.5)
                        Text("1.0 Saniye (Varsayılan)").tag(1.0)
                        Text("2.0 Saniye").tag(2.0)
                        Text("5.0 Saniye").tag(5.0)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: updateInterval) { oldValue, newValue in
                        NotificationCenter.default.post(name: Notification.Name("UpdateIntervalChanged"), object: nil)
                    }
                    
                    Picker("Sıcaklık Birimi:", selection: $tempUnit) {
                        Text("Santigrat (°C)").tag("C")
                        Text("Fahrenhayt (°F)").tag("F")
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()
                }
            }
            .tabItem {
                Label("Genel", systemImage: "gearshape")
            }
            .padding(20)
            .frame(width: 450, height: 250)
            
            // Menu Bar Telemetry Tab
            Form {
                Section(header: Text("Menü Çubuğu Görünümü").font(.headline)) {
                    Picker("Gösterim Stili:", selection: $menuBarStyle) {
                        Text("Sadece Simge").tag("icon")
                        Text("CPU Kullanımı (%)").tag("cpu")
                        Text("Bellek Kullanımı (%)").tag("memory")
                        Text("Ağ Hızı (İndirme)").tag("network")
                        Text("Kombine (CPU + RAM)").tag("combined")
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: menuBarStyle) { oldValue, newValue in
                        NotificationCenter.default.post(name: Notification.Name("MenuBarStyleChanged"), object: nil)
                    }
                    
                    Text("Seçilen stil menü çubuğundaki simgenin yanında canlı olarak görüntülenecektir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
            .tabItem {
                Label("Menü Çubuğu", systemImage: "menubar.arrow.up.rectangle")
            }
            .padding(20)
            .frame(width: 450, height: 250)
        }
        .frame(width: 450, height: 250)
    }
    
    // Launch at login using ServiceManagement (or placeholder fallback)
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        #if os(macOS)
        // In macOS 13+, SMAppService can be used to easily enable launch at login
        // Since we target macOS 14+, we can implement this cleanly if needed.
        // For local command-line app, we print status.
        print("Launch at login toggled to: \(enabled)")
        #endif
    }
}
