//
//  TabContentView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct TabContentView: View {
    let selectedTab: AppTab
    @Binding var navigationPath: NavigationPath
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Set background color for the entire view
            themeManager.current.backgroundColor.ignoresSafeArea()
            
            // Tab content
            switch selectedTab {
            case .home:
                NavigationStack {
                    HomeView(startARExperience: {
                        // This will be handled by the coordinator
                    })
                    .navigationBarTitleDisplayMode(.inline)
                }
                .transition(.opacity)
                
            case .ar:
                NavigationStack(path: $navigationPath) {
                    ARPaintingContainerView()
                        .navigationBarHidden(true)
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
