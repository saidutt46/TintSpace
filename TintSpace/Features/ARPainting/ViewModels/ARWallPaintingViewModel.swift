//
//  ARWallPaintingViewModel.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

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
class ARWallPaintingViewModel: ObservableObject, ARSessionManagerDelegate {
    // MARK: - Published Properties
    
    /// Current state of the AR wall painting experience
    @Published var currentARState: ARWallPaintingState = .initializing
    
    /// Whether any walls have been detected
    @Published var hasDetectedWalls = false
    
    /// Collection of detected wall anchors
    @Published var detectedWallAnchors: [UUID: ARPlaneAnchor] = [:]
    
    /// Loading state for the AR view
    @Published var isLoading = true
    
    /// Message manager for user feedback
    @Published var messageManager = ARMessageManager()
    
    // MARK: - Private Properties
    
    /// AR session manager
    private let arSessionManager: ARSessionManager
    
    /// Reference to the AR view
    private var arView: ARView?
    
    /// Subscription for AR session updates
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(arSessionManager: ARSessionManager) {
        self.arSessionManager = arSessionManager
        
        // Configure the session manager
        arSessionManager.messageManager = messageManager
        arSessionManager.delegate = self
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
    }
    
    /// Stop the AR session
    func stopARSession() {
        arSessionManager.pauseSession()
    }
    
    /// Reset the AR session
    func resetARSession() {
        hasDetectedWalls = false
        detectedWallAnchors.removeAll()
        arSessionManager.restartSession()
    }
    
    // MARK: - UI Actions
    
    /// Show help information
    func showHelp() {
        LogManager.shared.info(message: "Help action triggered", category: "UI")
        // In a real implementation, this would show a help overlay or tutorial
    }
    
    // MARK: - ARSessionManagerDelegate
    
    func arSessionManager(_ manager: ARSessionManager, didChangeState state: ARWallPaintingState) {
        DispatchQueue.main.async {
            self.currentARState = state
            
            // Update UI state based on AR state
            switch state {
            case .wallsDetected, .wallSelected, .colorApplied:
                self.hasDetectedWalls = true
            case .scanning, .initializing, .paused:
                // Don't change hasDetectedWalls here to avoid UI flicker
                break
            case .limited(let reason):
                // Show appropriate message for limited tracking
                self.handleLimitedTracking(reason)
            case .failed(let error):
                // Already handled by session manager, but log it here too
                LogManager.shared.error("AR session failed: \(error.localizedDescription)", category: "ARViewModel")
            }
        }
    }
    
    func arSessionManager(_ manager: ARSessionManager, didDetectWall anchor: ARPlaneAnchor) {
        DispatchQueue.main.async {
            // Store the detected wall anchor
            self.detectedWallAnchors[anchor.identifier] = anchor
            
            // Update UI state
            self.hasDetectedWalls = true
            
            // Show user feedback
            self.messageManager.showMessage(
                "Wall detected!",
                duration: 2.0,
                position: .center,
                icon: "checkmark.circle",
                isImmediate: false
            )
            
            LogManager.shared.info(message: "ViewModel received wall detection: \(anchor.identifier)", category: "ARViewModel")
        }
    }
    
    func arSessionManager(_ manager: ARSessionManager, didUpdateWall anchor: ARPlaneAnchor) {
        DispatchQueue.main.async {
            // Update the stored wall anchor
            self.detectedWallAnchors[anchor.identifier] = anchor
            
            LogManager.shared.info(message: "ViewModel received wall update: \(anchor.identifier)", category: "ARViewModel")
        }
    }
    
    func arSessionManager(_ manager: ARSessionManager, didRemoveWall anchor: ARPlaneAnchor) {
        DispatchQueue.main.async {
            // Remove the wall anchor from storage
            self.detectedWallAnchors.removeValue(forKey: anchor.identifier)
            
            // Update UI state if all walls are gone
            if self.detectedWallAnchors.isEmpty {
                self.hasDetectedWalls = false
            }
            
            LogManager.shared.info(message: "ViewModel received wall removal: \(anchor.identifier)", category: "ARViewModel")
        }
    }
    
    func arSessionManager(_ manager: ARSessionManager, didEncounterError error: Error) {
        DispatchQueue.main.async {
            // Show error message to user
            self.messageManager.showMessage(
                "AR Error: \(error.localizedDescription)",
                duration: 4.0,
                position: .center,
                icon: "exclamationmark.triangle.fill",
                isImmediate: true
            )
            
            LogManager.shared.error("ARViewModel received error: \(error.localizedDescription)", category: "ARViewModel")
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle limited tracking states
    private func handleLimitedTracking(_ reason: ARCamera.TrackingState.Reason) {
        let (message, icon) = trackingLimitedMessage(for: reason)
        messageManager.showMessage(
            message,
            duration: 3.0,
            position: .center,
            icon: icon,
            isImmediate: false
        )
    }
    
    /// Generate appropriate message for tracking limitation
    private func trackingLimitedMessage(for reason: ARCamera.TrackingState.Reason) -> (String, String) {
        switch reason {
        case .initializing:
            return ("Initializing AR...", "timer")
        case .excessiveMotion:
            return ("Slow down, moving too fast", "hand.raised.slash")
        case .insufficientFeatures:
            return ("Not enough visual features, try a more textured area", "eye.trianglebadge.exclamationmark")
        case .relocalizing:
            return ("Relocalizing AR session...", "arrow.triangle.2.circlepath")
        @unknown default:
            return ("AR tracking limited", "exclamationmark.circle")
        }
    }
    
    /// Complete the loading process
    private func finishLoading() {
        isLoading = false
        LogManager.shared.info(message: "AR view initialization completed", category: "ARViewModel")
    }
}
