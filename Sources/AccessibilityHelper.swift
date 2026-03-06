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
    // Assumes `carbonFrame` has already been translated from AppKit geometry
    static func setWindowFrame(_ window: AXUIElement, appKitFrame carbonFrame: CGRect) {
        var position = carbonFrame.origin
        var size = carbonFrame.size
        
        let positionValue = AXValueCreate(AXValueType.cgPoint, &position)!
        let sizeValue = AXValueCreate(AXValueType.cgSize, &size)!
        
        // Initial force position
        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        
        // Initial force size
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        
        // Start a fast, aggressive repeating timer to pound the size/pos constraints
        // Electron apps continuously fight resize commands during transition animations
        var attempts = 0
        let maxAttempts = 5
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            attempts += 1
            
            var currentPos = carbonFrame.origin
            var currentSize = carbonFrame.size
            let posVal = AXValueCreate(AXValueType.cgPoint, &currentPos)!
            let sizeVal = AXValueCreate(AXValueType.cgSize, &currentSize)!
            
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
            
            if attempts >= maxAttempts {
                timer.invalidate()
                
                // If Accessibility failed or was ignored, fallback to AppleScript bounds manipulation
                // which often forcefully overrides Electron's internal restrictions
                // Note: AppleScript also expects Carbon coordinates
                fallbackToAppleScript(window: window, frame: carbonFrame)
            }
        }
    }
    
    // Gets the PID of the application owning the window, and uses AppleScript to forcefully resize it
    static private func fallbackToAppleScript(window: AXUIElement, frame: CGRect) {
        var pid: pid_t = 0
        let error = AXUIElementGetPid(window, &pid)
        guard error == .success else { return }
        
        if let app = NSRunningApplication(processIdentifier: pid), let bundleId = app.bundleIdentifier {
            // Calculate absolute bottom-left AppKit bounds for AppleScript
            let x = Int(frame.origin.x)
            let y = Int(frame.origin.y)
            let width = Int(frame.size.width)
            let height = Int(frame.size.height)
            
            let scriptSource = """
            tell application id "\(bundleId)"
                set bounds of front window to {\(x), \(y), \(x + width), \(y + height)}
            end tell
            """
            
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let scriptObject = NSAppleScript(source: scriptSource) {
                    scriptObject.executeAndReturnError(&error)
                    if let err = error {
                        print("AppleScript fallback failed for \(bundleId): \(err)")
                    }
                }
            }
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
