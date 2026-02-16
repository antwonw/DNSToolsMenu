import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var eventMonitor: EventMonitor?
    
    // Windows logic (Keeps them alive)
    var settingsWindow: NSWindow?
    var historyWindow: NSWindow?
    
    // Shared Database
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([HistoryItem.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
            // 1. Setup the Popover (Menu Bar UI)
            var contentView = ContentView()
            
            // Connect the buttons to the AppDelegate functions
            contentView.onOpenSettings = { [weak self] in
                self?.openSettings()
            }
            contentView.onOpenHistory = { [weak self] in
                self?.openHistory()
            }
            
            let finalView = contentView.modelContainer(sharedModelContainer)
            
            popover.contentViewController = NSHostingController(rootView: finalView)
            popover.behavior = .transient
            
            // 2. Setup the Menu Bar Icon
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "DNSTools")
                button.action = #selector(mouseClickHandler)
                button.target = self
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
            
            // 3. Monitor clicks outside
            eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let strongSelf = self, strongSelf.popover.isShown {
                    strongSelf.closePopover(sender: event)
                }
            }
        }

    @objc func mouseClickHandler() {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            // Right Click Menu
            let menu = NSMenu()
            
            let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
            settings.target = self
            settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
            menu.addItem(settings)
            
            let history = NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "h")
            history.target = self
            history.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
            menu.addItem(history)
            
            menu.addItem(NSMenuItem.separator())
            
            let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
            quit.target = self
            menu.addItem(quit)
            
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else {
            // Left Click Popover
            togglePopover(nil)
        }
    }
    
    func togglePopover(_ sender: Any?) {
        if popover.isShown { closePopover(sender: sender) }
        else { showPopover(sender: sender) }
    }

    func showPopover(sender: Any?) {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
            // Force focus so typing works immediately
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
    
    // --- MANUAL WINDOW MANAGEMENT (FIXED) ---

    @objc func openSettings() {
            // Force the app to the front first
            NSApp.activate(ignoringOtherApps: true)
            
            if let window = settingsWindow {
                window.makeKeyAndOrderFront(nil)
                return
            }
            
            let view = SettingsView()
            let controller = NSHostingController(rootView: view)
            
            let window = NSWindow(contentViewController: controller)
            window.title = "Settings"
            // Ensure style mask includes .titled
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            
            window.delegate = self
            self.settingsWindow = window
            
            // Key step: Order front regardless
            window.makeKeyAndOrderFront(nil)
        }
        
        @objc func openHistory() {
            // Force the app to the front first
            NSApp.activate(ignoringOtherApps: true)
            
            if let window = historyWindow {
                window.makeKeyAndOrderFront(nil)
                return
            }
            
            let view = HistoryView().modelContainer(sharedModelContainer)
            let controller = NSHostingController(rootView: view)
            
            let window = NSWindow(contentViewController: controller)
            window.title = "History"
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            
            window.delegate = self
            self.historyWindow = window
            
            window.makeKeyAndOrderFront(nil)
        }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// Helper to nil out the variable when window is closed (optional but clean)
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == settingsWindow { settingsWindow = nil }
            if window == historyWindow { historyWindow = nil }
        }
    }
}
