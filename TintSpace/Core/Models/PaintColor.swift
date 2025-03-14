//
//  PaintColor.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

/// Represents a paint color that can be applied to walls
struct PaintColor: Identifiable, Equatable, Codable {
    // Unique identifier for the color
    let id: UUID
    
    // Name of the color (e.g., "Ocean Blue")
    let name: String
    
    // Color components - these are what we'll encode/decode
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    // Computed property for SwiftUI Color
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
    
    // Color category (e.g., warm, cool, neutral)
    let category: ColorCategory
    
    // Optional brand name if this is a predefined brand color
    let brandName: String?
    
    // Optional code (e.g., "B-117" for brand reference)
    let code: String?
    
    // Whether this is a user favorite
    var isFavorite: Bool = false
    
    // Optional timestamp for when this color was last used
    var lastUsed: Date?
    
    // Enum for color categories
    enum ColorCategory: String, Codable, CaseIterable {
        case warm
        case cool
        case neutral
        case vibrant
        case pastel
        case custom
    }
    
    // Primary initializer
    init(id: UUID = UUID(), name: String, red: Double, green: Double, blue: Double, opacity: Double = 1.0,
         category: ColorCategory, brandName: String? = nil, code: String? = nil, isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.category = category
        self.brandName = brandName
        self.code = code
        self.isFavorite = isFavorite
    }
    
    // Convenience initializer from SwiftUI Color
    init(id: UUID = UUID(), name: String, color: Color, category: ColorCategory,
         brandName: String? = nil, code: String? = nil, isFavorite: Bool = false) {
        // Convert SwiftUI Color to components
        // This is a simplified approach - for production, you'd need a more robust solution
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        self.init(
            id: id,
            name: name,
            red: Double(red),
            green: Double(green),
            blue: Double(blue),
            opacity: Double(alpha),
            category: category,
            brandName: brandName,
            code: code,
            isFavorite: isFavorite
        )
    }
    
    // Equatable implementation
    static func == (lhs: PaintColor, rhs: PaintColor) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Create a UIColor from this PaintColor (useful for RealityKit materials)
    func toUIColor() -> UIColor {
        return UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(opacity))
    }
}

// Extension to add Color-from-UIColor initializer for iOS 14 compatibility
extension Color {
    init(uiColor: UIColor) {
        self.init(red: Double(uiColor.rgba.red),
                  green: Double(uiColor.rgba.green),
                  blue: Double(uiColor.rgba.blue),
                  opacity: Double(uiColor.rgba.alpha))
    }
}

// UIColor extension to extract RGBA components
extension UIColor {
    var rgba: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}
