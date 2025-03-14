//
//  Constants.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation
import SwiftUI

/// App-wide constants
enum Constants {
    // Feature flags
    enum Features {
        static let enableHandGestures = false
        static let enableCloudSync = false
        static let enableMultiRoomDetection = false
    }
    
    // AR configuration
    enum AR {
        static let wallDetectionConfidenceThreshold: Float = 0.7
        static let maxWallDistance: Float = 5.0 // meters
        static let maxTrackedWalls = 10
        static let wallIndicatorColor = Color.blue.opacity(0.3)
        static let selectedWallIndicatorColor = Color.blue.opacity(0.5)
    }
    
    // UI configuration
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let animationDuration: Double = 0.3
        
        static let primaryColor = Color.blue
        static let secondaryColor = Color.purple
        static let accentColor = Color.orange
        static let errorColor = Color.red
        
        static let shadowRadius: CGFloat = 4
        static let shadowOpacity: CGFloat = 0.2
        static let shadowOffset = CGSize(width: 0, height: 2)
    }
    
    // Storage keys
    enum StorageKeys {
        static let recentColors = "TintSpace_RecentColors"
        static let favoriteColors = "TintSpace_FavoriteColors"
        static let userPreferences = "TintSpace_UserPreferences"
        static let lastViewedOnboarding = "TintSpace_LastViewedOnboarding"
    }
    
    // Limits
    enum Limits {
        static let maxRecentColors = 10
        static let maxFavoriteColors = 50
        static let maxUndoHistory = 20
    }
}
