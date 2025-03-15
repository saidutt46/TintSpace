//
//  ARWallPaintingViewModel.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

/// ViewModel for managing the AR wall painting experience
class ARWallPaintingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether the AR experience has detected any walls
    @Published var hasDetectedWalls = false
    
    // MARK: - Private Properties
    
    /// AR session manager
    @ObservedObject var arSessionManager: ARSessionManager
    
    /// AR Message manager
    @Published var messageManager = ARMessageManager()
    
    /// Reference to the AR view
    private var arView: ARView?
    
    /// Subscription for AR session updates
    private var cancellables = Set<AnyCancellable>()
    
    /// loading bool to manager ar view
    @Published var isLoading = true
    
    // MARK: - Initialization
    
    init(arSessionManager: ARSessionManager) {
        self.arSessionManager = arSessionManager
        // Set the session manager's message manager
        arSessionManager.messageManager = messageManager
        setupSubscriptions()
    }
    
    // MARK: - AR Setup
    
    /// Set up the AR view and configure the session manager
    func setupARView(_ arView: ARView) {
        self.arView = arView
        arSessionManager.arView = arView
        
        // Set up callback for session initialization
        arSessionManager.onARSessionInitialized = { [weak self] in
            self?.finishLoading()
        }
        
        // Set a timeout for loading state in case AR fails to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.isLoading == true {
                self?.finishLoading()
                LogManager.shared.warning("AR initialization timed out", category: "AR")
            }
        }
    }
    
    /// Start the AR session
    func startARSession() {
        arSessionManager.startSession()
        finishLoading()
    }
    
    /// Stop the AR session
    func stopARSession() {
        arSessionManager.pauseSession()
    }
    
    /// Reset the AR session
    func resetARSession() {
        hasDetectedWalls = false
        arSessionManager.restartSession()
    }
    
    // MARK: - UI Actions
    
    /// Show help information
    func showHelp() {
        LogManager.shared.info(message: "Help action triggered", category: "UI")
        // In a real implementation, this would show a help overlay or tutorial
    }
    
    // MARK: - Private Methods
    
    /// Set up subscriptions to AR session events
    private func setupSubscriptions() {
        // Subscribe to wall detection notifications
        NotificationCenter.default
            .publisher(for: .wallDetected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.hasDetectedWalls = true
            }
            .store(in: &cancellables)
    }
    
    private func finishLoading() {
        isLoading = false
        LogManager.shared.info(message: "AR view initialization completed", category: "AR")
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    /// Notification fired when a wall is detected
    static let wallDetected = Notification.Name("wallDetected")
}
