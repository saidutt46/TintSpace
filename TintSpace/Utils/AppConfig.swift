//
//  AppConfig.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation

/// Application-wide configuration settings
struct AppConfig {
    // App version information (in a real app, you'd pull these from Info.plist)
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // Feature configuration
    static let isDebugMode = false
    
    #if DEBUG
    static let environment = Environment.development
    #else
    static let environment = Environment.production
    #endif
    
    // Environment enum
    enum Environment {
        case development
        case staging
        case production
        
        var description: String {
            switch self {
            case .development: return "Development"
            case .staging: return "Staging"
            case .production: return "Production"
            }
        }
    }
    
    // AR configuration
    struct AR {
        static let defaultWallDetectionMode: WallDetectionMode = .automatic
        
        enum WallDetectionMode {
            case automatic  // App detects walls automatically
            case manual     // User manually identifies walls
        }
    }
    
    // Analytics configuration
    struct Analytics {
        static let isEnabled = true
        static let anonymousTracking = true
    }
}
