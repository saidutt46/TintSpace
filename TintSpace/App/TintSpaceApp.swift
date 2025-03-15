//
//  TintSpaceApp.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

@main
struct TintSpaceApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var arSessionManager = ARSessionManager()
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .environmentObject(themeManager)
                .environmentObject(arSessionManager)
                .onAppear {
                    LogManager.shared.info(message: "TintSpace UI appeared", category: "UI")
                }
        }
    }
}
