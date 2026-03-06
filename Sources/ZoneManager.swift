import AppKit

struct Zone {
    let index: Int
    /// Rect in AppKit coordinates (bottom-left origin)
    let rect: CGRect
    
    /// Converts this AppKit rect to Carbon accessibility coordinates (top-left origin).
    func getCarbonRect() -> CGRect {
        // Find the screen containing this rect
        let screens = NSScreen.screens
        // A simple heuristic for multi-monitor: which screen contains the center
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let screenOptional = screens.first(where: { NSMouseInRect(center, $0.frame, false) }) ?? screens.first
        guard let screen = screenOptional else { return rect }
        
        let screenFrame = screen.frame
        let mainScreen = screens.first!
        
        // Translate Y to Carbon coordinates
        // Carbon top-left origin across the whole desktop space.
        // AppKit has Y=0 at the bottom of the *primary* screen.
        
        // The Y coordinate in Carbon for the top of the rect
        // top edge in AppKit is maxY.
        // Carbon Y = (main screen height) - (AppKit maxY)
        let carbonY = mainScreen.frame.height - rect.maxY
        
        return CGRect(
            x: rect.minX,
            y: carbonY,
            width: rect.width,
            height: rect.height
        )
    }
}

class ZoneManager {
    static let shared = ZoneManager()
    
    // Per-monitor layout configurations
    var layoutsByScreen: [String: LayoutConfiguration] = [:]
    let fallbackLayout: LayoutConfiguration = LayoutConfiguration.defaultTemplates[1] // Default Three Columns
    
    // Set default padding to 0 as requested by the user
    var padding: CGFloat = 0.0
    
    /// Computes the active zones for the given screen based on the current relative layout configuration
    func getZones(for screen: NSScreen) -> [Zone] {
        var zones = [Zone]()
        let screenRect = screen.visibleFrame // Ignores menu bar and dock
        let screenName = screen.localizedName
        let layout = layoutsByScreen[screenName] ?? fallbackLayout
        
        for (index, relativeRect) in layout.relativeZones.enumerated() {
            // Apply padding logic inside the zone calculations.
            // When padding is 0, windows will snap completely flush to edges.
            
            // Convert relative (0.0 - 1.0) coordinates to absolute screen points
            let absoluteX = screenRect.minX + (relativeRect.minX * screenRect.width)
            let absoluteY = screenRect.minY + (relativeRect.minY * screenRect.height)
            let computedWidth = relativeRect.width * screenRect.width
            let computedHeight = relativeRect.height * screenRect.height
            
            // Inset the physical box by the configured padding
            let zoneRect = CGRect(x: absoluteX, y: absoluteY, width: computedWidth, height: computedHeight)
                .insetBy(dx: padding / 2.0, dy: padding / 2.0)
            // DIAGNOSTICS FOR ELECTRON Vertical MONITOR BEHAVIOR
            let logPath = "/tmp/oz_zone_math.txt"
            let logMsg = """
            --- SNAPPING MATH ---
            Screen: \(screen.localizedName)
            AppKit Origin: \(absoluteX), \(absoluteY)
            Carbon Rect: \(zoneRect)
            """
            
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write((logMsg + "\n").data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                try? (logMsg + "\n").write(toFile: logPath, atomically: true, encoding: .utf8)
            }
            
            zones.append(Zone(index: index, rect: zoneRect))
        }
        
        return zones
    }
    
    /// Finds the zone that best matches the mouse cursor location
    func getZoneFor(mouseLocation: NSPoint, on screen: NSScreen) -> Zone? {
        let zones = getZones(for: screen)
        // Find which zone contains the mouse
        return zones.first(where: { $0.rect.contains(mouseLocation) })
    }
}
