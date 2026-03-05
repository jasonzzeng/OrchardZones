import AppKit

// Entry point for the application.
// We manually instantiate the NSApplication and its delegate to run as a purely background/status bar app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Prevents the app from appearing in the Dock
app.setActivationPolicy(.accessory)

app.run()
