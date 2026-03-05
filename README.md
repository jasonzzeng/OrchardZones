# OrchardZones for macOS
> **⚠️ BETA VERSION:** OrchardZones is currently in active development.
> **Note:** The "Custom Layout" editor currently has a known bug where mouse clicks are not registered correctly to split or merge zones. Please use the predefined Templates in the meantime.

This is a native macOS alternative to Microsoft PowerToys FancyZones, written in Swift using AppKit and the Accessibility APIs. It is designed to run in the background (as a status bar app) and allows you to snap windows to predefined zones when dragging them.

## Requirements
- macOS 12+ (Apple Silicon supported natively)
- Xcode Command Line Tools installed (run `xcode-select --install` in your terminal if you haven't already).

## Installation

### Option 1: Download Pre-Compiled App (Recommended)
1. Go to the [Releases](https://github.com/jasonzzeng/OrchardZones/releases) page.
2. Download the `OrchardZones.app.zip` file from the latest release.
3. Extract the zip file and drag `OrchardZones.app` to your `Applications` folder.
4. If you get a warning that the app cannot be opened because the developer cannot be verified, `Right-Click` the app icon, select `Open`, and click `Open` again in the dialog.

### Option 2: Build from Source
1. Open Terminal on your Mac.
2. Navigate to the folder containing this `Package.swift` file.
3. Build the executable:
   ```bash
   swift build -c release
   ```
4. Find the compiled executable and run it:
   ```bash
   .build/release/OrchardZones
   ```

### Accessibility Permissions

Because this app needs to monitor mouse movements globally and modify the size and position of other applications' windows, it **must** be granted Accessibility permissions in macOS.

1. Go to **System Settings > Privacy & Security > Accessibility**.
2. If you are running the app via Terminal, you must grant permissions to **Terminal** (or iTerm, Warp, etc.).
3. The app will prompt you or log a message when it starts if it lacks the required permissions.
4. Restart the app once permissions are granted.

## Usage

1. Run the app in the background. It will place a small icon in your menu bar (top right).
2. Grab the title bar of any normal application window.
3. While dragging, **press and hold the Shift key** to reveal the drop zones (currently configured to a 3-column layout).
4. Drop the window inside a zone to snap it!
