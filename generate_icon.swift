import AppKit
import CoreGraphics
import Foundation

func createIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let image = NSImage(size: size)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    
    // Background gradient: sleek teal to dark green per user reference
    let colors = [
        NSColor(calibratedRed: 0.0, green: 0.5, blue: 0.3, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.0, green: 0.3, blue: 0.15, alpha: 1.0).cgColor
    ] as CFArray
    let gradientSpace = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: gradientSpace, colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
    
    // Define the Apple Silhouette Center
    let center = CGPoint(x: 512, y: 460) // Shifted down slightly to account for the leaf
    
    // Draw Apple Logo as white shape
    let fontName = "AppleLogo" // San Francisco / system font often maps  to Apple logo
    let fontSize: CGFloat = 850
    let text = "" as NSString
    
    // Try to draw using system font instead if AppleLogo font is missing
    let font = NSFont.systemFont(ofSize: fontSize)
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle
    ]
    
    // Calculate bounding box to perfectly center the text
    let textSize = text.size(withAttributes: attributes)
    let textRect = CGRect(
        x: (1024 - textSize.width) / 2,
        y: (1024 - textSize.height) / 2 + 30, // Adjust vertical center
        width: textSize.width,
        height: textSize.height
    )
    
    text.draw(in: textRect, withAttributes: attributes)
    
    // The user wants a grid of windows INSIDE the apple.
    // We will draw it by "punching" holes (drawing using `.clear` blend mode) or just drawing the background color over the white area.
    ctx.setBlendMode(.clear)
    ctx.setFillColor(NSColor.clear.cgColor)
    ctx.setStrokeColor(NSColor.clear.cgColor)
    
    // Or we can just draw lines of the background color if blending is tricky
    ctx.setBlendMode(.normal)
    let lineColors = [
        NSColor(calibratedRed: 0.0, green: 0.4, blue: 0.22, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.0, green: 0.35, blue: 0.18, alpha: 1.0).cgColor
    ] as CFArray
    let lineGradient = CGGradient(colorsSpace: gradientSpace, colors: lineColors, locations: [0, 1])!
    
    // Let's punch out rectangles so it looks like an inner grid.
    func punchWindow(rect: CGRect) {
        let path = CGPath(rect: rect, transform: nil)
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])
        ctx.resetClip()
    }
    
    // Add grid lines representing the "zones" inside the apple logo as requested by the mockup.
    let gridCenter = CGPoint(x: 512, y: 460)
    let gridWidth: CGFloat = 400
    let gridHeight: CGFloat = 400
    
    let gridRect = CGRect(x: gridCenter.x - gridWidth/2, y: gridCenter.y - gridHeight/2, width: gridWidth, height: gridHeight)
    
    // Vertical splitter 1 at 35%
    let v1 = gridRect.minX + gridRect.width * 0.35
    
    // Vertical splitter 2 at 70% (bottom half only)
    let v2 = gridRect.minX + gridRect.width * 0.70
    
    // Horizontal splitter 1 at 30% (left side)
    let h1 = gridRect.minY + gridRect.height * 0.30
    
    // Horizontal splitter 2 at 70% (left side)
    let h2 = gridRect.minY + gridRect.height * 0.70
    
    // Horizontal splitter 3 at 50% (right side)
    let h3 = gridRect.minY + gridRect.height * 0.50
    
    let lineThickness: CGFloat = 16
    
    // Let's just draw transparent "gaps" in the grid using the background color to act as a stencil over the white apple.
    ctx.setBlendMode(.normal)
    ctx.setFillColor(NSColor(calibratedRed: 0.0, green: 0.35, blue: 0.2, alpha: 1.0).cgColor) // Approximate center gradient color
    
    // Outline of the grid to define its scope (a thick stroke)
    let framePath = CGMutablePath()
    framePath.addRect(gridRect.insetBy(dx: -lineThickness/2, dy: -lineThickness/2))
    ctx.addPath(framePath)
    ctx.setLineWidth(lineThickness)
    ctx.setStrokeColor(NSColor(calibratedRed: 0.0, green: 0.35, blue: 0.2, alpha: 1.0).cgColor)
    ctx.strokePath()
    
    // Left vertical line
    ctx.fill(CGRect(x: v1 - lineThickness/2, y: gridRect.minY, width: lineThickness, height: gridRect.height))
    
    // Right vertical line (only bottom half)
    ctx.fill(CGRect(x: v2 - lineThickness/2, y: gridRect.minY, width: lineThickness, height: h3 - gridRect.minY))
    
    // Left horizontal 1
    ctx.fill(CGRect(x: gridRect.minX, y: h1 - lineThickness/2, width: v1 - gridRect.minX, height: lineThickness))
    
    // Left horizontal 2
    ctx.fill(CGRect(x: gridRect.minX, y: h2 - lineThickness/2, width: v1 - gridRect.minX, height: lineThickness))
    
    // Right horizontal 3
    ctx.fill(CGRect(x: v1 - lineThickness/2, y: h3 - lineThickness/2, width: gridRect.maxX - v1 + lineThickness/2, height: lineThickness))
    
    
    image.unlockFocus()
    
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else { return }
    let url = URL(fileURLWithPath: "/tmp/generated_icon.png")
    try? pngData.write(to: url)
}

createIcon()
