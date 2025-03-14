//
//  HomeView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  HomeView.swift
//  TintSpace
//
//  Created on 3/13/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var startARExperience: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Hero Section
                VStack(spacing: 16) {
                    Text("TintSpace")
                        .font(AppFont.hero)
                        .foregroundColor(themeManager.current.primaryBrandColor)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    Text("Visualize your walls in color")
                        .font(AppFont.title2)
                        .foregroundColor(themeManager.current.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1 : 0)
                        .offset(y: isAnimating ? 0 : 15)
                        .padding(.bottom, 8)
                    
//                    // Paint brush illustration - this would be an image in a real app
//                    ZStack {
//                        RoundedRectangle(cornerRadius: 20)
//                            .fill(themeManager.current.secondaryBackgroundColor)
//                            .frame(height: 200)
//                            .shadow(color: themeManager.current.shadowColor, radius: 10, x: 0, y: 5)
//                        
//                        // Placeholder for app screenshot/illustration
//                        Text("AR Wall Painting Preview")
//                            .foregroundColor(themeManager.current.secondaryTextColor)
//                    }
//                    .opacity(isAnimating ? 1 : 0)
//                    .scaleEffect(isAnimating ? 1 : 0.9)
                }
                .padding(.top, 40)
                
                // Feature highlights
                VStack(alignment: .leading, spacing: 20) {
                    FeatureItem(
                        icon: "paintpalette.fill",
                        title: "Visualize Before You Buy",
                        description: "See how colors look on your walls without purchasing paint samples."
                    )
                    
                    FeatureItem(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Compare Side by Side",
                        description: "Apply different colors to different walls to find perfect combinations."
                    )
                    
                    FeatureItem(
                        icon: "camera.filters",
                        title: "Paint Finish Simulation",
                        description: "See how matte, satin, and gloss finishes affect your chosen color."
                    )
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .padding(.horizontal)
                
                // Action Button
                Button(action: {
                    LogManager.shared.userAction("StartARPressed")
                    startARExperience()
                }) {
                    HStack {
                        Image(systemName: "arkit")
                            .font(.title3)
                        Text("Start AR Experience")
                            .font(AppFont.buttonLabel)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.current.primaryButtonBackgroundColor)
                    .foregroundColor(themeManager.current.primaryButtonTextColor)
                    .cornerRadius(16)
                }
                .opacity(isAnimating ? 1 : 0)
                .offset(y: isAnimating ? 0 : 20)
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .background(themeManager.current.backgroundColor.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            LogManager.shared.ui("HomeView appeared", category: "UI")
        }
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(themeManager.current.primaryBrandColor)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppFont.headline)
                    .foregroundColor(themeManager.current.primaryTextColor)
                
                Text(description)
                    .font(AppFont.subheadline)
                    .foregroundColor(themeManager.current.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(themeManager.current.cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: themeManager.current.shadowColor, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light mode preview
            HomeView(startARExperience: {})
                .environmentObject(ThemeManager())
                .previewDisplayName("Light Mode")
            
            // Dark mode preview
            HomeView(startARExperience: {})
                .environmentObject(ThemeManager())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
