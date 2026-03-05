import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var editorWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Request accessibility permissions
        let trusted = AccessibilityHelper.checkAccessibilityAccess(prompt: true)
        print("Accessibility trusted: \(trusted)")
        
        if !trusted {
            // Give user a prompt to enable Accessibility and exit.
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "OrchardZones needs accessibility permissions to resize windows and monitor mouse events. Please enable them in System Settings > Privacy & Security > Accessibility and restart the app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApplication.shared.terminate(self)
        }
        
        // Ensure LayoutStore initializes and loads preferences
        _ = LayoutStore.shared
        
        // Setup status bar item
        setupMenu()
        
        // Start monitoring events
        EventMonitor.shared.start()
        
        print("OrchardZones started successfully.")
    }
    
    func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // Using a standard SF Symbol available on macOS 11+
            button.image = NSImage(systemSymbolName: "uiwindow.split.2x1", accessibilityDescription: "OrchardZones")
            // Fallback if SF symbol not found
            if button.image == nil {
                button.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: "OrchardZones")
            }
            if button.image == nil {
                button.title = "OZ"
            }
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Layout Editor...", action: #selector(showLayoutEditor), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OrchardZones", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func showLayoutEditor() {
        if editorWindow == nil {
            let contentView = LayoutEditorView()
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.center()
            window.setFrameAutosaveName("LayoutEditorWindow")
            window.title = "OrchardZones Editor"
            window.contentView = NSHostingView(rootView: contentView)
            
            self.editorWindow = window
            
            // Bring to front
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            editorWindow?.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func quit() {
        EventMonitor.shared.stop()
        NSApplication.shared.terminate(self)
    }
}
