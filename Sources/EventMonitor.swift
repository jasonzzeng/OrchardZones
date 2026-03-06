import AppKit

class EventMonitor {
    static let shared = EventMonitor()
    
    private var dragMonitor: Any?
    private var mouseUpMonitor: Any?
    private var keyMonitor: Any?
    
    private var isDragging = false
    private var showZones = false
    
    private var draggedWindow: AXUIElement?
    private var activeScreen: NSScreen?
    private var activeZone: Zone?
    
    func start() {
        // Listen to mouse drag globally
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.handleMouseDrag(event)
        }
        
        // Listen to mouse up to trigger the snap
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.handleMouseUp(event)
        }
        
        // Listen to modifier key changes to toggle zone visibility mid-drag
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
    }
    
    func stop() {
        if let dragMonitor = dragMonitor { NSEvent.removeMonitor(dragMonitor) }
        if let mouseUpMonitor = mouseUpMonitor { NSEvent.removeMonitor(mouseUpMonitor) }
        if let keyMonitor = keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }
    
    private func handleMouseDrag(_ event: NSEvent) {
        if !isDragging {
            // First drag event, get the window under the cursor
            isDragging = true
            draggedWindow = AccessibilityHelper.getFocusedWindow()
        }
        
        // We require Shift to be held down to show the zones
        showZones = event.modifierFlags.contains(.shift)
        
        if showZones {
            updateOverlay(mouseLocation: NSEvent.mouseLocation)
        } else {
            OverlayWindowManager.shared.hide()
            activeZone = nil
        }
    }
    
    private func handleMouseUp(_ event: NSEvent) {
        if isDragging {
            if showZones, let window = draggedWindow, let zone = activeZone {
                // Snap the window to the target zone
                AccessibilityHelper.setWindowFrame(window, appKitFrame: zone.getCarbonRect())
            }
            
            // Reset state
            isDragging = false
            showZones = false
            draggedWindow = nil
            activeZone = nil
            OverlayWindowManager.shared.hide()
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        if isDragging {
            showZones = event.modifierFlags.contains(.shift)
            if showZones {
                updateOverlay(mouseLocation: NSEvent.mouseLocation)
            } else {
                OverlayWindowManager.shared.hide()
                activeZone = nil
            }
        }
    }
    
    private func updateOverlay(mouseLocation: NSPoint) {
        // Find which screen the mouse is currently on
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            activeScreen = screen
            activeZone = ZoneManager.shared.getZoneFor(mouseLocation: mouseLocation, on: screen)
            OverlayWindowManager.shared.show(activeScreen: screen, activeZone: activeZone)
        }
    }
}
