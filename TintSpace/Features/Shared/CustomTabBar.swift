//
//  CustomTabBar.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var themeManager: ThemeManager
    
    // Tab info for rendering
    private let tabs: [(tab: AppTab, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.ar, "paintbrush.fill", "Paint"),
        (.colors, "swatchpalette.fill", "Colors"),
        (.settings, "gear", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tab) { tabInfo in
                TabButton(
                    icon: tabInfo.icon,
                    label: tabInfo.label,
                    isSelected: selectedTab == tabInfo.tab,
                    action: { selectedTab = tabInfo.tab }
                )
                // Equal width for all tabs
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 12)
        // Use safe area insets to ensure the tab bar extends to the bottom of the screen
        .background(
            themeManager.current.backgroundColor // Use a more visible color for testing
                .shadow(color: themeManager.current.shadowColor, radius: 8, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // Function to get the bottom safe area inset
    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 8 // Fallback value
        }
        return max(window.safeAreaInsets.bottom, 8)
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Background circle for selected state
                    if isSelected {
                        Circle()
                            .fill(themeManager.current.primaryBrandColor.opacity(0.15))
                            .frame(width: 46, height: 46)
                    }
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ?
                                         themeManager.current.primaryBrandColor :
                                         themeManager.current.secondaryTextColor)
                }
                
                // Label
                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ?
                                    themeManager.current.primaryBrandColor :
                                    themeManager.current.secondaryTextColor)
            }
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode
            VStack {
                Spacer()
                CustomTabBar(selectedTab: .constant(.home))
                    .environmentObject(ThemeManager())
            }
            .previewDisplayName("Light Mode")
            
            // Dark mode
            VStack {
                Spacer()
                CustomTabBar(selectedTab: .constant(.ar))
                    .environmentObject(ThemeManager())
                    .preferredColorScheme(.dark)
            }
            .previewDisplayName("Dark Mode")
        }
    }
}
