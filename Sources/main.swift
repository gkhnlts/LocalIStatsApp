import AppKit

// Initialize shared NSApplication instance
let app = NSApplication.shared

// Define AppDelegate to hold the MenuBarManager instance
class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize our menu bar manager once app finishes booting
        menuBarManager = MenuBarManager()
    }
}

// Instantiate and bind the delegate
let delegate = AppDelegate()
app.delegate = delegate

// Set the application to run as an accessory (no dock icon, sits in menu bar)
app.setActivationPolicy(.accessory)

// Start the macOS event loop
app.run()
