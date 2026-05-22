import AppKit
import SwiftUI
import Combine

public class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let monitor = SystemMonitor()
    private var contextMenu: NSMenu!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        
        // Create Status Item in Menu Bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Configure status item button
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "LocalIStats")
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .transient // Closes automatically when clicking outside
        popover.contentViewController = NSHostingController(rootView: PopoverView(monitor: monitor))
        
        // Create Right-Click Context Menu
        contextMenu = NSMenu()
        
        let aboutItem = NSMenuItem(title: "LocalIStats Hakkında", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        contextMenu.addItem(aboutItem)
        
        let settingsItem = NSMenuItem(title: "Ayarlar...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        contextMenu.addItem(settingsItem)
        
        contextMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Çıkış", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
        
        // Observe model updates to refresh menu bar title
        monitor.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarText()
            }
            .store(in: &cancellables)
        
        // Observe menu bar configuration changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleStyleChange), name: Notification.Name("MenuBarStyleChanged"), object: nil)
        
        // Observe custom triggers
        NotificationCenter.default.addObserver(self, selector: #selector(closePopover), name: Notification.Name("ClosePopover"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(openSettingsWindow), name: Notification.Name("OpenSettings"), object: nil)
        
        // Run initial menu bar setup
        updateMenuBarText()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleStatusItemClick(_ sender: AnyObject?) {
        guard let event = NSApp.currentEvent else {
            togglePopover(sender)
            return
        }
        
        if event.type == .rightMouseUp {
            // Show context menu on right-click
            closePopover()
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            // Reset menu to nil so left-click works again
            statusItem.menu = nil
        } else {
            togglePopover(sender)
        }
    }
    
    private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Activate application to receive focus
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    @objc private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    @objc private func openSettingsWindow() {
        closePopover()
        
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 250),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "LocalIStats Ayarları"
            window.contentViewController = NSHostingController(rootView: SettingsView())
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func handleStyleChange() {
        updateMenuBarText()
    }
    
    private func updateMenuBarText() {
        guard let button = statusItem.button else { return }
        
        let style = UserDefaults.standard.string(forKey: "menuBarStyle") ?? "icon"
        
        switch style {
        case "cpu":
            button.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "CPU")
            button.title = String(format: " %.0f%%", monitor.cpu.totalUsage)
            button.imagePosition = .imageLeft
        case "memory":
            button.image = NSImage(systemSymbolName: "memorychip", accessibilityDescription: "RAM")
            button.title = String(format: " %.0f%%", monitor.memory.usagePercentage)
            button.imagePosition = .imageLeft
        case "network":
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Ağ")
            button.title = " " + monitor.network.downloadSpeedFormatted
            button.imagePosition = .imageLeft
        case "combined":
            button.image = nil
            button.title = String(format: "C:%.0f%% R:%.0f%%", monitor.cpu.totalUsage, monitor.memory.usagePercentage)
            button.imagePosition = .noImage
        default: // "icon"
            button.image = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "LocalIStats")
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "LocalIStats"
        alert.informativeText = "macOS Sistem İzleme Uygulaması\n\nSürüm: 1.0.0\nCPU, RAM, Ağ, Disk, Pil ve Sıcaklık izleme.\n\nGeliştirici: Gokhan"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
