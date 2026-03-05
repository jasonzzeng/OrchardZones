import Foundation
import CoreGraphics

/// Represents a raw structural layout capable of computing actual screen rectangles.
struct LayoutConfiguration: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String
    
    /// Predefined types vs Custom User layouts
    var isCustom: Bool
    
    /// Each zone is defined by a relative fractional rect:
    /// x, y, width, height are all in the range [0.0, 1.0]
    /// Origin (0,0) is bottom-left (AppKit native).
    var relativeZones: [CGRect]
    
    static func == (lhs: LayoutConfiguration, rhs: LayoutConfiguration) -> Bool {
        return lhs.id == rhs.id
    }
}

extension LayoutConfiguration {
    /// Default built-in templates
    static let defaultTemplates: [LayoutConfiguration] = [
        // Two Columns
        LayoutConfiguration(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Two Columns", isCustom: false, relativeZones: [
                CGRect(x: 0, y: 0, width: 0.5, height: 1.0),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0)
            ]
        ),
        // Three Columns
        LayoutConfiguration(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Three Columns", isCustom: false, relativeZones: [
                CGRect(x: 0, y: 0, width: 1.0/3.0, height: 1.0),
                CGRect(x: 1.0/3.0, y: 0, width: 1.0/3.0, height: 1.0),
                CGRect(x: 2.0/3.0, y: 0, width: 1.0/3.0, height: 1.0)
            ]
        ),
        // Four Columns
        LayoutConfiguration(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Four Columns", isCustom: false, relativeZones: [
                CGRect(x: 0, y: 0, width: 0.25, height: 1.0),
                CGRect(x: 0.25, y: 0, width: 0.25, height: 1.0),
                CGRect(x: 0.5, y: 0, width: 0.25, height: 1.0),
                CGRect(x: 0.75, y: 0, width: 0.25, height: 1.0)
            ]
        ),
        // Two Rows
        LayoutConfiguration(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Two Rows", isCustom: false, relativeZones: [
                CGRect(x: 0, y: 0.5, width: 1.0, height: 0.5), // Top (AppKit origin is bottom)
                CGRect(x: 0, y: 0, width: 1.0, height: 0.5)    // Bottom
            ]
        ),
        // Three Rows
        LayoutConfiguration(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            name: "Three Rows", isCustom: false, relativeZones: [
                CGRect(x: 0, y: 2.0/3.0, width: 1.0, height: 1.0/3.0),
                CGRect(x: 0, y: 1.0/3.0, width: 1.0, height: 1.0/3.0),
                CGRect(x: 0, y: 0, width: 1.0, height: 1.0/3.0)
            ]
        ),
        // 2x2 Grid
        LayoutConfiguration(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            name: "2x2 Grid", isCustom: false, relativeZones: [
                // Top row
                CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
                // Bottom row
                CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
            ]
        )
    ]
}
