//
//  TabContentView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

/// Main content view that changes based on selected tab
struct TabContentView: View {
    let selectedTab: AppTab
    let startARExperience: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Set background color for the entire view
            themeManager.current.backgroundColor.ignoresSafeArea()
            
            // Tab content
            switch selectedTab {
            case .home:
                NavigationStack {
                    HomeView(startARExperience: startARExperience)
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(.opacity)
                
            case .colors:
                NavigationStack {
                    ColorLibraryView()
                        .navigationTitle("My Colors")
                }
                .transition(.opacity)
                
            case .settings:
                NavigationStack {
                    SettingsView()
                        .navigationTitle("Settings")
                }
                .transition(.opacity)
            }
        }
    }
}
