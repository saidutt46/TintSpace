//
//  ContentView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var arSessionManager: ARSessionManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            themeManager.current.backgroundColor
                .ignoresSafeArea()
            
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
                    
                    // Paint brush illustration - this would be an image in a real app
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(themeManager.current.secondaryBackgroundColor)
                            .frame(height: 200)
                            .shadow(color: themeManager.current.shadowColor, radius: 10, x: 0, y: 5)
                        
                        // Gradient color swatches
                        HStack(spacing: 12) {
                            ColorSwatch(color: .paintTeal)
                            ColorSwatch(color: .paintSkyBlue)
                            ColorSwatch(color: .paintSage)
                            ColorSwatch(color: .paintCoral)
                            ColorSwatch(color: .paintLilac)
                        }
                        .padding(.horizontal, 20)
                    }
                    .opacity(isAnimating ? 1 : 0)
                    .scaleEffect(isAnimating ? 1 : 0.9)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    Button(action: {
                        LogManager.shared.userAction("StartARPressed")
                        // This would navigate to the AR experience
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
                    
                    Button(action: {
                        themeManager.toggleLightDark()
                        LogManager.shared.userAction("ThemeToggled", details: ["newTheme": themeManager.themeType.rawValue])
                    }) {
                        HStack {
                            Image(systemName: themeManager.current == .dark ? "sun.max.fill" : "moon.fill")
                                .font(.body)
                            Text("Toggle Theme")
                                .font(AppFont.smallButtonLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.secondaryButtonBackgroundColor)
                        .foregroundColor(themeManager.current.secondaryButtonTextColor)
                        .cornerRadius(16)
                    }
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 10)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
            LogManager.shared.ui("ContentView appeared", category: "UI")
        }
    }
}

struct ColorSwatch: View {
    let color: Color
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(color)
            .frame(width: 50, height: isAnimating ? 120 : 80)
            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
            .animation(
                Animation.easeInOut(duration: 2)
                    .repeatForever(autoreverses: true)
                    .delay(Double.random(in: 0...1)),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ThemeManager())
            .environmentObject(ARSessionManager())
    }
}
