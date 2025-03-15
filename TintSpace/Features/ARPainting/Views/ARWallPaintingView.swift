//
//  ARWallPaintingView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

//
//  ARWallPaintingView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

import SwiftUI
import ARKit
import RealityKit

/// Main view for the AR wall painting experience
struct ARWallPaintingView: View {
    // MARK: - Properties
    
    /// The view model that manages the AR experience
    @StateObject private var viewModel: ARWallPaintingViewModel
    
    /// Action to perform when the close button is tapped
    var onClose: () -> Void
    
    init(arSessionManager: ARSessionManager, onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
        _viewModel = StateObject(wrappedValue: ARWallPaintingViewModel(arSessionManager: arSessionManager))
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // AR Content Container
            ARViewContainer(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            if viewModel.isLoading {
                ARLoadingView()
            }
            
            // UI Overlays
            VStack(spacing: 0) {
                // Top toolbar
                topToolbar
                
                Spacer()
                messageOverlay
                
                // Bottom control panel
                controlBar
            }
        }
        .onAppear {
            viewModel.startARSession()
        }
        .onDisappear {
            viewModel.stopARSession()
        }
    }
    
    // MARK: - UI Components
    
    /// Top toolbar with help and close buttons
    private var topToolbar: some View {
        HStack {
            // Help button
            Button(action: {
                viewModel.showHelp()
            }) {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Close button
            Button(action: {
                onClose()
            }) {
                Image(systemName: "xmark.circle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    /// Primary UI notification message overlay
    private var messageOverlay: some View {
        GeometryReader { geometry in
            if let message = viewModel.messageManager.currentMessage {
                MessageView(message: message)
                    .position(messagePosition(for: message.position, in: geometry))
                    .animation(.easeInOut, value: message.id)
            }
        }
    }
    
    /// Bottom controls for AR features
    private var controlBar: some View {
        HStack {
            IconButton(image: "reset", label: "Reset View", action: viewModel.resetARSession, renderAsTemplate: true)
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.8))
    }
    
    private func messagePosition(for position: ARMessageManager.MessagePosition, in geometry: GeometryProxy) -> CGPoint {
        switch position {
        case .top:
            return CGPoint(x: geometry.size.width / 2, y: 100)
        case .center:
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        case .bottom:
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height - 100)
        }
    }
}

/// SwiftUI representation of ARView
struct ARViewContainer: UIViewRepresentable {
    // The view model that manages the AR experience
    var viewModel: ARWallPaintingViewModel
    
    /// Creates the ARView
    func makeUIView(context: Context) -> ARView {
        // Create and configure the AR view
        let arView = ARView(frame: .zero)
        
        // Store the ARView in the view model
        viewModel.setupARView(arView)
        
        return arView
    }
    
    /// Updates the ARView when SwiftUI state changes
    func updateUIView(_ uiView: ARView, context: Context) {
        // Nothing to do here as the view model handles AR view updates
    }
}

// MARK: - Previews

struct ARWallPaintingView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock ARSessionManager for previews
        ARWallPaintingView(
            arSessionManager: ARSessionManager(),
            onClose: {}
        )
    }
}

struct ARLoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)

            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Initializing AR...")
                    .foregroundColor(.white)
                    .font(.headline)
                    .padding(.top)
            }
        }
    }
}

struct IconButton: View {
    let image: String
    let label: String
    let action: () -> Void
    let renderAsTemplate: Bool
    var isActive: Bool = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(image)
                    .resizable()
                    .renderingMode(renderAsTemplate ? .template : .original)
                    .foregroundColor(isActive ? .blue : .white)
                    .frame(width: 28, height: 28)
                    .padding(10)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
                Text(label)
                    .font(AppFont.caption1)
                    .foregroundColor(.white)
            }
        }
    }
}
