//
//  AppCoordinator.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

/// Possible tabs in the app
enum AppTab {
    case home
    case colors
    case settings
}

/// Manages app navigation and state
class AppCoordinatorViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var isARExperiencePresented = false
    
    /// Navigate to a specific tab
    func navigateTo(_ tab: AppTab) {
        selectedTab = tab
    }
    
    /// Present the AR experience
    func presentARExperience() {
        isARExperiencePresented = true
    }
    
    /// Dismiss the AR experience
    func dismissARExperience() {
        isARExperiencePresented = false
    }
}

/// Coordinator for app-wide navigation
struct AppCoordinator: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var arSessionManager: ARSessionManager
    @StateObject private var viewModel = AppCoordinatorViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content
            TabContentView(
                selectedTab: viewModel.selectedTab,
                startARExperience: {
                    viewModel.presentARExperience()
                }
            )
            .padding(.bottom, 70) // Add padding for custom tab bar
            
            // Custom tab bar - applied at the very bottom
            VStack(spacing: 0) {
                Spacer()
                CustomTabBar(selectedTab: $viewModel.selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .fullScreenCover(isPresented: $viewModel.isARExperiencePresented) {
            ARWallPaintingView(
                arSessionManager: arSessionManager,
                onClose: {
                    viewModel.dismissARExperience()
                }
            )
        }
        .environmentObject(viewModel)
        .onAppear {
            LogManager.shared.info(message: "AppCoordinator appeared", category: "Navigation")
        }
    }
}

struct AppCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        AppCoordinator()
            .environmentObject(ThemeManager())
    }
}
