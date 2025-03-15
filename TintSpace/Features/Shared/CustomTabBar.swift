//
//  CustomTabBar.swift
//  TintSpace
//

import SwiftUI

/// Custom tab bar for the app
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 0) {
            // Home tab
            TabBarButton(
                isSelected: selectedTab == .home,
                icon: "house.fill",
                title: "Home",
                action: { selectedTab = .home }
            )
            
            // Colors tab
            TabBarButton(
                isSelected: selectedTab == .colors,
                icon: "circle.grid.3x3.fill",
                title: "My Colors",
                action: { selectedTab = .colors }
            )
            
            // Settings tab
            TabBarButton(
                isSelected: selectedTab == .settings,
                icon: "gear",
                title: "Settings",
                action: { selectedTab = .settings }
            )
        }
        .frame(height: 70)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(themeManager.current.cardBackgroundColor)
                .shadow(color: themeManager.current.shadowColor, radius: 2)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}

/// Button for tab bar items
struct TabBarButton: View {
    let isSelected: Bool
    let icon: String
    let title: String
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(isSelected ? themeManager.current.primaryBrandColor : themeManager.current.secondaryTextColor)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Previews

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            CustomTabBar(selectedTab: .constant(.home))
                .environmentObject(ThemeManager())
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            CustomTabBar(selectedTab: .constant(.colors))
                .environmentObject(ThemeManager())
                .preferredColorScheme(.dark)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Dark Mode")
        }
    }
}
