//
//  AppColors.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

extension Color {
    // MARK: - Hex Color Initializer
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - App Background Colors
    
    // Light/Dark mode backgrounds
    static let lightBackground = Color(hex: "FFFFFF")  // Pure white
    static let darkBackground = Color(hex: "121212")   // Material dark
    
    // Secondary backgrounds
    static let lightSecondaryBackground = Color(hex: "F8F8FA")  // Very light gray with blue tint
    static let darkSecondaryBackground = Color(hex: "1E1E22")   // Dark gray with blue tint
    
    // Tertiary backgrounds
    static let lightTertiaryBackground = Color(hex: "F0F0F4")  // Light gray with blue tint
    static let darkTertiaryBackground = Color(hex: "2C2C30")   // Medium dark gray
    
    // Card/Tile backgrounds
    static let lightCardBackground = Color(hex: "FFFFFF")      // White
    static let darkCardBackground = Color(hex: "242428")       // Dark card
    
    // MARK: - Text Colors
    
    // Primary text
    static let lightText = Color(hex: "000000")  // Black
    static let darkText = Color(hex: "FFFFFF")   // White
    
    // Secondary text
    static let lightSecondaryText = Color(hex: "505050")  // Dark gray
    static let darkSecondaryText = Color(hex: "BBBBBB")   // Light gray
    
    // Tertiary text
    static let lightTertiaryText = Color(hex: "909090")  // Medium gray
    static let darkTertiaryText = Color(hex: "888888")   // Lighter medium gray
    
    // MARK: - Brand Colors
    
    // Main TintSpace brand colors - Fresh paint-inspired palette
    static let tintBrush = Color(hex: "068D9D")      // Primary brand color - Teal blue
    static let tintCanvas = Color(hex: "6461A0")     // Secondary brand color - Violet purple
    static let tintSwatch = Color(hex: "53A548")     // Tertiary brand color - Fresh green
    
    // Supporting brand colors
    static let tintHighlight = Color(hex: "F2D06B")  // Yellow accent
    static let tintAccent = Color(hex: "EE6C4D")     // Orange-red accent
    
    // MARK: - Feedback Colors
    
    // Status/feedback colors
    static let successGreen = Color(hex: "4BB543")   // Success indicator
    static let warningYellow = Color(hex: "FFB302")  // Warning indicator
    static let errorRed = Color(hex: "E63946")       // Error indicator
    static let infoBlue = Color(hex: "2986CC")       // Information indicator
    
    // MARK: - AR-specific Colors
    
    // AR visualization colors
    static let wallHighlight = Color(hex: "068D9D").opacity(0.3)     // Wall detection
    static let selectedWallHighlight = Color(hex: "068D9D").opacity(0.6)  // Selected wall
    static let arPlacementGuide = Color(hex: "068D9D")               // Placement guide
    static let arControlIndicator = Color(hex: "F2D06B")             // AR controls indicator
    
    // MARK: - Paint Palette Categories
    
    // Neutral paint colors
    static let paintWhite = Color(hex: "FCFCFC")
    static let paintOffWhite = Color(hex: "F5F5F5")
    static let paintLightGray = Color(hex: "D8D8D8")
    static let paintMediumGray = Color(hex: "979797")
    static let paintCharcoal = Color(hex: "404040")
    static let paintBlack = Color(hex: "111111")
    
    // Warm paint colors
    static let paintBeige = Color(hex: "F5F1E6")
    static let paintCream = Color(hex: "F9EFD9")
    static let paintTan = Color(hex: "D3B89C")
    static let paintCamel = Color(hex: "BE9973")
    static let paintTerracotta = Color(hex: "C8553D")
    static let paintRust = Color(hex: "A4392D")
    
    // Cool paint colors
    static let paintSkyBlue = Color(hex: "A4CADE")
    static let paintNavy = Color(hex: "1A4B73")
    static let paintTeal = Color(hex: "4A8992")
    static let paintMint = Color(hex: "91C9B0")
    static let paintSage = Color(hex: "BAC49F")
    static let paintForest = Color(hex: "195E3F")
    
    // Accent paint colors
    static let paintLilac = Color(hex: "C5B4E3")
    static let paintPlum = Color(hex: "7B506F")
    static let paintSunflower = Color(hex: "FFD567")
    static let paintMustard = Color(hex: "D09E45")
    static let paintCoral = Color(hex: "FF8274")
    static let paintBerry = Color(hex: "A63D62")
}
