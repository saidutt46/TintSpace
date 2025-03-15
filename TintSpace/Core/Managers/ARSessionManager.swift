//
//  ARSessionManager.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import Foundation
import ARKit
import RealityKit
import Combine
import AVFoundation

/// Manages the ARKit session and related functionality
class ARSessionManager: NSObject, ARSessionDelegate, ObservableObject {
    // MARK: - Properties
    
    /// The ARView from RealityKit
    weak var arView: ARView?
    
    var onARSessionInitialized: (() -> Void)?
    
    /// Whether the AR session is running
    private(set) var isSessionRunning = false
    
    /// Error message if session fails
    private(set) var sessionErrorMessage: String?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // In ARSessionManager
    var messageManager: ARMessageManager?  // Non-optional but implicitly unwrapped
    
    // MARK: - AR Session Management
    
    /// Create an optimized configuration for wall detection
    private func createWallDetectionConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable vertical plane detection for walls
        configuration.planeDetection = [.vertical]
        
        // Enable automatic environment texturing
        configuration.environmentTexturing = .automatic
        
        // Enable scene reconstruction (LiDAR) if available
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
                LogManager.shared.info(message: "Scene reconstruction enabled", category: "AR")
            }
        }
        
        // Enable people occlusion if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
            LogManager.shared.info(message: "People occlusion enabled", category: "AR")
        }
        
        return configuration
    }
    
    /// Start the AR session
    func startSession() {
        guard let arView = arView else {
            sessionErrorMessage = "AR View not initialized"
            LogManager.shared.error("Failed to start AR session: AR View not initialized", category: "AR")
            return
        }
        
        // Check camera permissions
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                DispatchQueue.main.async {
                    // Set up AR session
                    arView.session.delegate = self
                    
                    // Configure and start the session
                    let configuration = self.createWallDetectionConfiguration()
                    arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                    
                    self.isSessionRunning = true
                    self.sessionErrorMessage = nil
                    self.onARSessionInitialized?()
                    
                    self.messageManager?.showMessage(
                        "AR Ready! 🏠\nScan your space to detect walls.",
                        duration: 3.0,
                        position: .center,
                        icon: "arkit",
                        isImmediate: true
                    )
                }
            } else {
                self.sessionErrorMessage = "Camera access is required for AR"
                LogManager.shared.error("Camera permission denied", category: "AR")
            }
        }
    }
    
    /// Pause the AR session
    func pauseSession() {
        arView?.session.pause()
        isSessionRunning = false
        LogManager.shared.info(message: "AR session paused", category: "AR")
    }
    
    /// Restart the AR session
    func restartSession() {
        pauseSession()
        
        // Wait briefly before restarting to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSession()
        }
    }
    
    // MARK: - ARSessionDelegate Methods
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        isSessionRunning = false
        sessionErrorMessage = "AR Session failed: \(error.localizedDescription)"
        LogManager.shared.error("AR session failed", category: "AR", error: error)
        self.messageManager?.showMessage("AR session failed: \(error.localizedDescription)", duration: 5.0, position: .center, icon: "exclamationmark.triangle")
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
                    LogManager.shared.info(message: "Detected vertical plane (potential wall)", category: "AR")

                    // Post notification for wall detection
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .wallDetected,
                            object: nil
                        )
                    }
                }
            }
        }
    }
}
