import AppKit
import ApplicationServices

class AccessibilityHelper {
    
    // Checks if the application currently has accessibility permissions enabled.
    // If prompt is true, it will prompt the user if access is denied.
    static func checkAccessibilityAccess(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return accessEnabled
    }
    
    // Returns the currently focused window as an AXUIElement
    static func getFocusedWindow() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedAppElement: CFTypeRef?
        var error = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedAppElement)
        
        guard error == .success, let focusedApp = focusedAppElement else {
            return nil
        }
        
        var focusedWindowElement: CFTypeRef?
        error = AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindowElement)
        
        guard error == .success, let focusedWindow = focusedWindowElement else {
            return nil
        }
        
        return (focusedWindow as! AXUIElement)
    }
    
    // Sets the frame (position and size) of the given window
    static func setWindowFrame(_ window: AXUIElement, frame: CGRect) {
        var position = frame.origin
        // Carbon coordinates for Accessibility: origin is top-left of the primary screen
        // AppKit coordinates: origin is bottom-left of the primary screen.
        // We assume 'frame' is passed in Accessibility coordinates (top-left).
        if let positionValue = AXValueCreate(AXValueType.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        
        var size = frame.size
        if let sizeValue = AXValueCreate(AXValueType.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        
        // Sometimes setting the size changes position slightly depending on the anchor. We set position again to be sure.
        if let positionValue = AXValueCreate(AXValueType.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
    }
    
    // Gets the frame of the given window
    static func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        
        var position = CGPoint.zero
        var size = CGSize.zero
        
        if AXValueGetValue(positionValue as! AXValue, AXValueType.cgPoint, &position),
           AXValueGetValue(sizeValue as! AXValue, AXValueType.cgSize, &size) {
            return CGRect(origin: position, size: size)
        }
        
        return nil
    }
}
