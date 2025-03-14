//
//  TintSpaceApp.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

@main
struct TintSpaceApp: App {
    // App delegate for lifecycle events
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // App-level state management
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var arSessionManager = ARSessionManager()
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(arSessionManager)
                .environmentObject(themeManager)
                .onAppear {
                    LogManager.shared.info(message: "TintSpace UI appeared", category: "UI")
                }
        }
    }
}
