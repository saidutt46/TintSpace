//
//  PaintFinish.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation

/// Represents different types of paint finishes
enum PaintFinish: String, Codable, CaseIterable, Identifiable {
    case matte = "Matte"
    case eggshell = "Eggshell"
    case satin = "Satin"
    case semiGloss = "Semi-Gloss"
    case gloss = "Gloss"
    
    var id: String { self.rawValue }
    
    // Material properties for RealityKit rendering
    var roughness: Float {
        switch self {
        case .matte: return 0.9
        case .eggshell: return 0.7
        case .satin: return 0.5
        case .semiGloss: return 0.3
        case .gloss: return 0.1
        }
    }
    
    // Metallic property for RealityKit rendering
    var metallic: Float {
        switch self {
        case .matte, .eggshell: return 0.0
        case .satin: return 0.05
        case .semiGloss: return 0.1
        case .gloss: return 0.2
        }
    }
    
    // Clear coat for RealityKit rendering (for added shine)
    var clearCoat: Float {
        switch self {
        case .matte, .eggshell: return 0.0
        case .satin: return 0.2
        case .semiGloss: return 0.5
        case .gloss: return 1.0
        }
    }
    
    // Simple description of each finish
    var description: String {
        switch self {
        case .matte:
            return "Flat, non-reflective finish. Good for hiding wall imperfections."
        case .eggshell:
            return "Slight sheen, more washable than matte. Popular for living rooms."
        case .satin:
            return "Velvety, pearl-like sheen. Durable and good for high-traffic areas."
        case .semiGloss:
            return "Visible shine, highly durable. Great for trim, doors, and cabinets."
        case .gloss:
            return "Highly reflective, mirror-like shine. Best for trim, doors, and accent areas."
        }
    }
}
