//
//  ARSessionManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

/// Manages the ARKit session and related functionality
class ARSessionManager: NSObject, ObservableObject {
    // Published properties to notify SwiftUI views of changes
    @Published var isSessionRunning = false
    @Published var sessionErrorMessage: String?
    
    // The ARView from RealityKit
    var arView: ARView?
    
    // AR Configuration
    private var configuration: ARWorldTrackingConfiguration
    
    // Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        // Initialize stored properties first
        self.configuration = ARWorldTrackingConfiguration()
        
        // Call super.init() before accessing instance methods
        super.init()
        
        // Now it's safe to call instance methods
        setupConfiguration()
        
        LogManager.shared.info(message: "ARSessionManager initialized", category: "AR")
    }
    
    private func setupConfiguration() {
        // Configure world tracking capabilities
        configuration.planeDetection = [.vertical]
        configuration.environmentTexturing = .automatic
        
        // Enable people occlusion for more realistic AR if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
            LogManager.shared.info(message: "People occlusion enabled", category: "AR")
        } else {
            LogManager.shared.info(message: "People occlusion not supported on this device", category: "AR")
        }
    }
    
    /// Initializes and starts the AR session
    func startSession() {
        guard let arView = arView else {
            sessionErrorMessage = "AR View not initialized"
            LogManager.shared.error("Failed to start AR session: AR View not initialized", category: "AR")
            return
        }
        
        // Start performance measurement
        LogManager.shared.measure("AR Session Startup") {
            // Set up AR session
            arView.session.delegate = self
            
            // Start AR session
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            isSessionRunning = true
            sessionErrorMessage = nil
            
            LogManager.shared.success("AR session started successfully", category: "AR")
        }
    }
    
    /// Pauses the AR session
    func pauseSession() {
        arView?.session.pause()
        isSessionRunning = false
        LogManager.shared.info(message: "AR session paused", category: "AR")
    }
    
    // Additional methods for wall detection, etc. will be added here
}

// MARK: - ARSessionDelegate
extension ARSessionManager: ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        isSessionRunning = false
        sessionErrorMessage = "AR Session failed: \(error.localizedDescription)"
        LogManager.shared.error("AR session failed", category: "AR", error: error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        isSessionRunning = false
        LogManager.shared.warning("AR session was interrupted", category: "AR")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        LogManager.shared.info(message: "AR session interruption ended", category: "AR")
        startSession()
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if planeAnchor.alignment == .vertical {
                    LogManager.shared.ar("Detected vertical plane: \(planeAnchor.identifier.uuidString)", category: "PlaneDetection")
                }
            }
        }
    }
}
