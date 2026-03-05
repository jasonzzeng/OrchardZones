import AppKit

class OverlayView: NSView {
    var zones: [Zone] = []
    var activeZone: Zone?
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Clear background
        NSColor.clear.set()
        dirtyRect.fill()
        
        // Draw each zone
        for zone in zones {
            let path = NSBezierPath(roundedRect: zone.rect, xRadius: 12, yRadius: 12)
            
            if let active = activeZone, active.index == zone.index {
                // Active zone highlight
                NSColor(calibratedRed: 0.2, green: 0.5, blue: 0.9, alpha: 0.5).setFill()
                NSColor(calibratedRed: 0.1, green: 0.4, blue: 0.8, alpha: 0.8).setStroke()
            } else {
                // Inactive zone
                NSColor(calibratedWhite: 0.1, alpha: 0.3).setFill()
                NSColor(calibratedWhite: 0.8, alpha: 0.5).setStroke()
            }
            
            path.lineWidth = 4.0
            path.fill()
            path.stroke()
        }
    }
    
    func update(zones: [Zone], activeZone: Zone?) {
        self.zones = zones
        self.activeZone = activeZone
        self.needsDisplay = true
    }
}

class OverlayWindowManager {
    static let shared = OverlayWindowManager()
    
    private var overlayWindows: [NSScreen: NSWindow] = [:]
    
    func show(activeScreen: NSScreen, activeZone: Zone?) {
        // Create windows for screens if they don't exist
        for screen in NSScreen.screens {
            if overlayWindows[screen] == nil {
                let rect = screen.frame
                let window = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = .floating // Above normal windows
                window.ignoresMouseEvents = true
                window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
                
                let view = OverlayView(frame: NSRect(origin: .zero, size: rect.size))
                window.contentView = view
                overlayWindows[screen] = window
            }
            
            // Render zones
            if let window = overlayWindows[screen], let view = window.contentView as? OverlayView {
                let zones = ZoneManager.shared.getZones(for: screen)
                // Convert screen coordinates to window-local coordinates for the view
                let localZones = zones.map { Zone(index: $0.index, rect: window.convertFromScreen($0.rect)) }
                
                let localActiveZone = (screen == activeScreen && activeZone != nil) ?
                    Zone(index: activeZone!.index, rect: window.convertFromScreen(activeZone!.rect)) : nil
                    
                view.update(zones: localZones, activeZone: localActiveZone)
                window.orderFront(nil)
            }
        }
    }
    
    func hide() {
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
    }
}
