//
//  ARPaintingView.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

/// The main AR view for wall detection and painting
struct ARPaintingView: View {
    // MARK: - Environment Properties
    
    @EnvironmentObject var themeManager: ThemeManager
    
    // MARK: - State Properties
    
    /// ViewModel for the AR painting view
    @StateObject private var viewModel: ARPaintingViewModel
    
    /// State for showing the wall detection guidance
    @State private var showWallDetectionGuide = true
    
    /// State for controlling the info panel
    @State private var showInfoPanel = false
    
    /// State for tracking animation of status messages
    @State private var isStatusMessageAnimating = false
    
    private let wallDetectionService: WallDetectionService

    // MARK: - Initialization
    
    /// Initialize with dependencies
    /// - Parameter arSessionManager: The AR session manager
    init(arSessionManager: ARSessionManager, wallDetectionService: WallDetectionService) {
//        arSessionManager = arSessionManager
        self.wallDetectionService = wallDetectionService
        
        // Initialize the view model with the existing services
        _viewModel = StateObject(wrappedValue: ARPaintingViewModel(
            arSessionManager: arSessionManager,
            wallDetectionService: wallDetectionService
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // AR Content View containing the RealityKit scene
            ARContentView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            // Handle tap to select a wall
                            viewModel.handleTap(at: value.location)
                        }
                )
            
            // Status message overlay
            if let statusMessage = viewModel.currentStatusMessage {
                VStack {
                    Spacer()
                    
                    ARStatusMessageView(message: statusMessage)
                        .padding(.bottom, 50) // Adjust based on your UI
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut(duration: 0.3), value: isStatusMessageAnimating)
                        .onAppear {
                            isStatusMessageAnimating = true
                        }
                        .onDisappear {
                            isStatusMessageAnimating = false
                        }
                }
            }
            
            // Wall detection guide overlay (when needed)
            if showWallDetectionGuide && viewModel.isDetectingWalls && viewModel.detectedWalls.isEmpty {
                WallDetectionGuideView {
                    showWallDetectionGuide = false
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showWallDetectionGuide)
            }
            
            // Top controls
            VStack {
                HStack {
                    // Info button
                    Button(action: {
                        showInfoPanel.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(themeManager.current.primaryBrandColor)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(themeManager.current.cardBackgroundColor.opacity(0.8))
                                    .shadow(radius: 2)
                            )
                    }
                    .accessibilityLabel("Session Information")
                    
                    Spacer()
                    
                    // Reset button
                    Button(action: {
                        viewModel.resetSession()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(themeManager.current.primaryBrandColor)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(themeManager.current.cardBackgroundColor.opacity(0.8))
                                    .shadow(radius: 2)
                            )
                    }
                    .accessibilityLabel("Reset AR Session")
                }
                .padding()
                
                Spacer()
            }
            
            // Info panel (when visible)
            if showInfoPanel {
                ARSessionInfoPanel(
                    sessionInfo: viewModel.sessionInfo,
                    detectedWallCount: viewModel.detectedWalls.count,
                    isTrackingLimited: viewModel.isTrackingLimited
                ) {
                    showInfoPanel = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: showInfoPanel)
            }
        }
        .onAppear {
            // Start AR session when view appears
            viewModel.startARSession()
        }
        .onDisappear {
            // Pause AR session when view disappears
            viewModel.pauseARSession()
        }
    }
}

// MARK: - AR Content View

/// SwiftUI wrapper for the RealityKit ARView
struct ARContentView: UIViewRepresentable {
    // View model reference
    var viewModel: ARPaintingViewModel
    
    // Create the ARView
    func makeUIView(context: Context) -> ARView {
        // Create and configure ARView
        let arView = ARView(frame: .zero)
        
        // Set up the view model with the AR view
        viewModel.setupARView(arView)
        
        return arView
    }
    
    // Update the ARView when SwiftUI state changes
    func updateUIView(_ uiView: ARView, context: Context) {
        // Nothing to do here as our view model handles updates
    }
}

// MARK: - Wall Detection Guide View

/// Guide view for helping users detect walls
struct WallDetectionGuideView: View {
    // Theme access
    @EnvironmentObject var themeManager: ThemeManager
    
    // Dismiss action
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Detecting Walls")
                .font(AppFont.title2)
                .foregroundColor(themeManager.current.primaryTextColor)
            
            Text("Slowly move your device to scan the room and detect walls.")
                .font(AppFont.body)
                .foregroundColor(themeManager.current.secondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Simple illustration of a scanning motion
            Image(systemName: "arrow.left.and.right.circle")
                .font(.system(size: 50))
                .foregroundColor(themeManager.current.primaryBrandColor)
            
            Button("Got it") {
                onDismiss()
            }
            .font(AppFont.buttonLabel)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(themeManager.current.primaryButtonBackgroundColor)
            .foregroundColor(themeManager.current.primaryButtonTextColor)
            .cornerRadius(12)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.current.cardBackgroundColor.opacity(0.95))
                .shadow(radius: 5)
        )
        .padding(20)
    }
}

// MARK: - AR Status Message View

/// Displays transient status messages for AR view
struct ARStatusMessageView: View {
    // Theme access
    @EnvironmentObject var themeManager: ThemeManager
    
    // Message to display
    var message: ARViewStatusMessage
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on message type
            Image(systemName: message.icon)
                .font(.title3)
                .foregroundColor(iconColor)
            
            Text(message.text)
                .font(AppFont.subheadline)
                .foregroundColor(themeManager.current.primaryTextColor)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.current.cardBackgroundColor.opacity(0.9))
                .shadow(radius: 3)
        )
        .padding(.horizontal, 16)
    }
    
    /// Color for the icon based on message type
    private var iconColor: Color {
        switch message.type {
        case .info:
            return themeManager.current.infoColor
        case .success:
            return themeManager.current.successColor
        case .warning:
            return themeManager.current.warningColor
        case .error:
            return themeManager.current.errorColor
        }
    }
}

// MARK: - AR Session Info Panel

/// Information panel showing AR session details
struct ARSessionInfoPanel: View {
    // Theme access
    @EnvironmentObject var themeManager: ThemeManager
    
    // AR session information
    let sessionInfo: [String: Any]
    let detectedWallCount: Int
    let isTrackingLimited: Bool
    
    // Dismiss action
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("AR Session Info")
                    .font(AppFont.title3)
                    .foregroundColor(themeManager.current.primaryTextColor)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.current.secondaryTextColor)
                }
            }
            
            Divider()
            
            // Tracking status
            HStack {
                Text("Tracking:")
                    .font(AppFont.headline)
                    .foregroundColor(themeManager.current.secondaryTextColor)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(isTrackingLimited ? themeManager.current.warningColor : themeManager.current.successColor)
                        .frame(width: 12, height: 12)
                    
                    Text(sessionInfo["trackingState"] as? String ?? "Unknown")
                        .font(AppFont.subheadline)
                        .foregroundColor(themeManager.current.primaryTextColor)
                }
            }
            
            // Detected walls
            HStack {
                Text("Detected Walls:")
                    .font(AppFont.headline)
                    .foregroundColor(themeManager.current.secondaryTextColor)
                
                Spacer()
                
                Text("\(detectedWallCount)")
                    .font(AppFont.subheadline)
                    .foregroundColor(themeManager.current.primaryTextColor)
            }
            
            // Lighting conditions
            HStack {
                Text("Lighting:")
                    .font(AppFont.headline)
                    .foregroundColor(themeManager.current.secondaryTextColor)
                
                Spacer()
                
                let intensity = sessionInfo["ambientIntensity"] as? CGFloat ?? 0
                let isLightingSufficient = intensity > 0.3
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(isLightingSufficient ? themeManager.current.successColor : themeManager.current.warningColor)
                        .frame(width: 12, height: 12)
                    
                    Text(String(format: "%.0f%%", intensity * 100))
                        .font(AppFont.subheadline)
                        .foregroundColor(themeManager.current.primaryTextColor)
                }
            }
            
            // Device capabilities
            VStack(alignment: .leading, spacing: 8) {
                Text("Device Capabilities:")
                    .font(AppFont.headline)
                    .foregroundColor(themeManager.current.secondaryTextColor)
                
                HStack {
                    Text("LiDAR:")
                    Spacer()
                    Text(sessionInfo["lidarSupported"] as? Bool == true ? "Available" : "Not Available")
                        .foregroundColor(themeManager.current.primaryTextColor)
                }
                .font(AppFont.footnote)
                
                HStack {
                    Text("People Occlusion:")
                    Spacer()
                    Text(sessionInfo["peopleOcclusionSupported"] as? Bool == true ? "Supported" : "Not Supported")
                        .foregroundColor(themeManager.current.primaryTextColor)
                }
                .font(AppFont.footnote)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.current.cardBackgroundColor.opacity(0.95))
                .shadow(radius: 5)
        )
        .padding(16)
    }
}

/// Preview provider for ARPaintingView
/// This file also contains test harnesses for AR functionality
struct ARPaintingView_Previews: PreviewProvider {
    static var previews: some View {
        ARPaintingViewPreviewContainer()
    }
}

/// A container for previewing AR painting functionality
/// Note: AR functionality doesn't work in previews, but this is useful for UI testing
struct ARPaintingViewPreviewContainer: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        TabView {
            ARPaintingViewMock()
                .environmentObject(themeManager)
        }
        .environmentObject(themeManager)
    }
}

/// A mock version of ARPaintingView that can be used in previews and tests
struct ARPaintingViewMock: View {
    // Mock status messages for UI testing
    @State private var showStatusMessage = true
    @State private var messageType: ARStatusMessageType = .info
    @State private var mockDetectionGuide = true
    @State private var mockInfoPanel = false
    
    /// Mock status message
    private var mockStatusMessage: ARViewStatusMessage? {
        guard showStatusMessage else { return nil }
        
        let text: String
        switch messageType {
        case .info:
            text = "Move device slowly to detect walls"
        case .success:
            text = "Wall detected successfully"
        case .warning:
            text = "Limited tracking quality"
        case .error:
            text = "Tracking lost - try resetting"
        }
        
        return ARViewStatusMessage(text: text, type: messageType, duration: 3.0)
    }
    
    /// Mock session info for testing
    private var mockSessionInfo: [String: Any] {
        return [
            "isRunning": true,
            "trackingState": "AR tracking normal",
            "ambientIntensity": 0.75,
            "ambientColorTemperature": 6500.0,
            "worldTrackingSupported": true,
            "peopleOcclusionSupported": true,
            "sceneReconstructionSupported": false,
            "lidarSupported": false
        ]
    }
    
    var body: some View {
        ZStack {
            // Mock AR content background
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            // Simulated AR content
            VStack {
                Spacer()
                
                Text("AR View Content")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("(AR preview not available)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            // Wall detection guide
            if mockDetectionGuide {
                WallDetectionGuideView {
                    mockDetectionGuide = false
                }
                .transition(.opacity)
                .animation(.easeInOut, value: mockDetectionGuide)
            }
            
            // Status message
            if let statusMessage = mockStatusMessage {
                VStack {
                    Spacer()
                    
                    ARStatusMessageView(message: statusMessage)
                        .padding(.bottom, 50)
                }
            }
            
            // Info panel
            if mockInfoPanel {
                ARSessionInfoPanel(
                    sessionInfo: mockSessionInfo,
                    detectedWallCount: 3,
                    isTrackingLimited: messageType == .warning
                ) {
                    mockInfoPanel = false
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: mockInfoPanel)
            }
            
            // Top controls
            VStack {
                HStack {
                    // Info button
                    Button(action: {
                        mockInfoPanel.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .shadow(radius: 2)
                            )
                    }
                    
                    Spacer()
                    
                    // Reset button
                    Button(action: {
                        // Simulate reset action
                        messageType = .info
                        showStatusMessage = true
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.8))
                                    .shadow(radius: 2)
                            )
                    }
                }
                .padding()
                
                Spacer()
            }
            
            // Test controls at bottom
            VStack {
                Spacer()
                
                HStack {
                    Button("Info") {
                        messageType = .info
                        showStatusMessage = true
                    }
                    .buttonStyle(TestButtonStyle(.blue))
                    
                    Button("Success") {
                        messageType = .success
                        showStatusMessage = true
                    }
                    .buttonStyle(TestButtonStyle(.green))
                    
                    Button("Warning") {
                        messageType = .warning
                        showStatusMessage = true
                    }
                    .buttonStyle(TestButtonStyle(.orange))
                    
                    Button("Error") {
                        messageType = .error
                        showStatusMessage = true
                    }
                    .buttonStyle(TestButtonStyle(.red))
                }
                .padding()
                
                Button("Toggle Guide") {
                    mockDetectionGuide.toggle()
                }
                .buttonStyle(TestButtonStyle(.purple))
                .padding(.bottom, 20)
            }
        }
    }
}

/// Custom button style for test controls
struct TestButtonStyle: ButtonStyle {
    var color: Color
    
    init(_ color: Color) {
        self.color = color
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
