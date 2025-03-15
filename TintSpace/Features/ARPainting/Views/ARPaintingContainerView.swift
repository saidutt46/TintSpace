//
//  ARPaintingContainerView.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import SwiftUI
import ARKit
import RealityKit

/// Container view for the AR painting experience that configures and injects dependencies
struct ARPaintingContainerView: View {
    // MARK: - Environment Properties
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - State Objects
    
    /// AR session manager - created once per container instance
    @StateObject private var arSessionManager = ARSessionManager()
    
    /// Wall detection service - create ONCE at this level
    @StateObject private var wallDetectionService: WallDetectionService
       
    /// Status notification manager for app-wide status messages
    @StateObject private var statusManager = StatusNotificationManager()
    
    // MARK: - State Properties
    
    /// Whether to show a loading screen while ARKit initializes
    @State private var isLoading = true
    
    init() {
        // Create the wall detection service as a StateObject
        // This ensures it's created ONCE and persisted
        let service = WallDetectionService(arSessionManager: ARSessionManager())
        _wallDetectionService = StateObject(wrappedValue: service)
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main AR view when not loading
            if !isLoading {
                ARPaintingView(arSessionManager: arSessionManager, wallDetectionService: wallDetectionService)
                    .environmentObject(statusManager)
                    .environmentObject(themeManager)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Loading screen
                ARLoadingView {
                    // When loading is complete
                    withAnimation {
                        isLoading = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Check AR capabilities on appear
            checkARCapabilities()
            
            // Simulate a brief loading time to ensure AR components are ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut) {
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Check if the device supports AR and show relevant messages
    private func checkARCapabilities() {
        if !arSessionManager.isWorldTrackingSupported {
            statusManager.showError(
                "Your device doesn't support AR required for wall detection.",
                actionTitle: "Learn More",
                action: {
                    // Could open a help screen explaining requirements
                }
            )
        }
    }
}

/// Loading screen shown while AR components initialize
struct ARLoadingView: View {
    // MARK: - Environment Properties
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    // MARK: - Properties
    
    var onReady: () -> Void
    
    // MARK: - State Properties
    
    @State private var rotation: Double = 0
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 24) {
            // App logo or icon
            Image(systemName: "paintbrush.fill")
                .font(.system(size: 70))
                .foregroundColor(themeManager.current.primaryBrandColor)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
            
            Text("Preparing AR Experience")
                .font(AppFont.title2)
                .foregroundColor(themeManager.current.primaryTextColor)
            
            Text("TintSpace is setting up your augmented reality experience. This will only take a moment.")
                .font(AppFont.body)
                .foregroundColor(themeManager.current.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Progress indicator
            ProgressView()
                .scaleEffect(1.2)
                .padding(.top, 16)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(themeManager.current.cardBackgroundColor)
                .shadow(radius: 10)
        )
        .padding(32)
        .onAppear {
            // Signal ready after animations have time to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onReady()
            }
        }
    }
}

// MARK: - Previews

struct ARPaintingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        ARPaintingContainerView()
            .environmentObject(ThemeManager())
    }
}
