//
//  AppTypography.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

struct AppFont {
    // MARK: - System Font Methods
    
    static func system(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: size, weight: weight, design: design)
    }
    
    // MARK: - Display Fonts (Largest)
    
    static let largeTitle = system(size: 34, weight: .bold)
    static let hero = system(size: 40, weight: .bold, design: .rounded)
    static let title1 = system(size: 28, weight: .bold)
    static let title2 = system(size: 22, weight: .bold)
    static let title3 = system(size: 20, weight: .bold)
    
    // MARK: - Content Fonts
    
    static let headline = system(size: 17, weight: .semibold)
    static let body = system(size: 17)
    static let callout = system(size: 16)
    static let subheadline = system(size: 15)
    static let footnote = system(size: 13)
    static let caption1 = system(size: 12)
    static let caption2 = system(size: 11)
    
    // MARK: - Specialized App Fonts
    
    static let arInstructions = system(size: 18, weight: .medium, design: .rounded)
    static let buttonLabel = system(size: 16, weight: .semibold)
    static let smallButtonLabel = system(size: 14, weight: .medium)
    static let inputFieldText = system(size: 14, weight: .regular)
    static let colorName = system(size: 15, weight: .medium)
    static let colorBrand = system(size: 12, weight: .regular)
    static let stat = system(size: 16, weight: .medium, design: .monospaced)
    static let tag = system(size: 12, weight: .semibold)
}
