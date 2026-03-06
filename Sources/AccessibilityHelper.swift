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
        /*
         * Fix macOS bug!
         * --------------
         * macOS has a bug, when you move & resize a window downward across dual monitors, the window is not resized correctly.
         * We briefly shrink the height by 10 pixels to bypass the validation rejection, and then snap to the final size.
         */
        if NSScreen.screens.count > 1 {
            var sizeValue = CGSize(width: carbonFrame.size.width, height: carbonFrame.size.height - 10)
            if let sizeAXValue = AXValueCreate(.cgSize, &sizeValue) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeAXValue)
            }
        }
        
        // Start a fast, aggressive cascade to pound the size/pos constraints
        // Electron apps continuously fight resize commands during transition animations
        let maxAttempts = 10
        for i in 0..<maxAttempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + (0.05 * Double(i))) { [window, carbonFrame] in
                var currentPos = carbonFrame.origin
                var currentSize = carbonFrame.size
                
                if let posVal = AXValueCreate(AXValueType.cgPoint, &currentPos) {
                    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
                }
                if let sizeVal = AXValueCreate(AXValueType.cgSize, &currentSize) {
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
                }
                
                // On the final attempt, execute the AppleScript fallback directly if needed
                if i == maxAttempts - 1 {
                    fallbackToAppleScript(window: window, frame: carbonFrame)
                }
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
