//
//  AppCoordinator.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  AppCoordinator.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct AppCoordinator: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var arSessionManager: ARSessionManager
    @State private var selectedTab: AppTab = .home
    
    // Used for programmatic navigation between tabs
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabContentView(selectedTab: selectedTab, navigationPath: $navigationPath)
                .padding(.bottom, 70) // Add padding for custom tab bar
            
            // Custom tab bar - applied at the very bottom
            VStack(spacing: 0) {
                Spacer()
                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            LogManager.shared.userAction("AppCoordinator appeared")
        }
    }
    
    // Method to programmatically navigate to a specific tab
    func navigateTo(_ tab: AppTab) {
        selectedTab = tab
    }
}

struct AppCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        AppCoordinator()
            .environmentObject(ThemeManager())
            .environmentObject(ARSessionManager())
    }
}
