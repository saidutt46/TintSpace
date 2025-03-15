//
//  SimpleARSessionManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

//
//  SimpleARSessionManager.swift
//  TintSpace
//

import Foundation
import ARKit
import RealityKit
import Combine

/// A simplified AR session manager for basic AR functionality
class SimpleARSessionManager: NSObject {
    // MARK: - Properties
    
    /// Reference to the AR view
    private weak var arView: ARView?
    
    /// Indicates if the AR session is running
    private(set) var isSessionRunning = false
    
    /// Current tracking state
    private(set) var trackingState: TrackingState = .normal
    
    /// Event handler for tracking state changes
    var onTrackingStateChanged: ((TrackingState) -> Void)?
    
    /// Event handler for frame updates
    var onFrameUpdated: ((ARFrame) -> Void)?
    
    /// Event handler for anchors being added
    var onAnchorsAdded: (([ARAnchor]) -> Void)?
    
    /// Custom tracking state enum
    enum TrackingState: Equatable {
        case normal
        case limited(reason: ARCamera.TrackingState.Reason)
        case notAvailable
    }
    
    // MARK: - Configuration
    
    /// Configure the manager with an AR view
    /// - Parameter arView: The AR view to manage
    func configure(arView: ARView) {
        self.arView = arView
        
        // Set self as the session delegate
        arView.session.delegate = self
        
        print("SimpleARSessionManager: Configured with AR view")
    }
    
    // MARK: - Session Control
    
    /// Start the AR session
    func startSession() {
        guard let arView = arView else {
            print("SimpleARSessionManager: Cannot start session - AR view not set")
            return
        }
        
        // Create configuration optimized for wall detection
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable vertical plane detection for walls
        configuration.planeDetection = [.vertical]
        
        // Enable people occlusion if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
            print("SimpleARSessionManager: People occlusion enabled")
        }
        
        // Enable automatic environment texturing
        configuration.environmentTexturing = .automatic
        
        // Start the AR session
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isSessionRunning = true
        
        print("SimpleARSessionManager: AR session started")
    }
    
    /// Pause the AR session
    func pauseSession() {
        guard let arView = arView else { return }
        
        arView.session.pause()
        isSessionRunning = false
        
        print("SimpleARSessionManager: AR session paused")
    }
    
    /// Restart the AR session
    func restartSession() {
        pauseSession()
        
        // Wait a moment before restarting to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSession()
        }
    }
}

// MARK: - ARSessionDelegate

extension SimpleARSessionManager: ARSessionDelegate {
    /// Called when the session has updated its frame
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update the tracking state
        updateTrackingState(from: frame.camera)
        
        // Notify observers about the frame update
        onFrameUpdated?(frame)
    }
    
    /// Update the tracking state based on camera information
    private func updateTrackingState(from camera: ARCamera) {
        // Determine new tracking state
        let newState: TrackingState
        
        switch camera.trackingState {
        case .normal:
            newState = .normal
        case .notAvailable:
            newState = .notAvailable
        case .limited(let reason):
            newState = .limited(reason: reason)
        }
        
        // Only notify if state changed
        if newState != trackingState {
            trackingState = newState
            onTrackingStateChanged?(newState)
        }
    }
    
    /// Called when anchors are added to the session
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        onAnchorsAdded?(anchors)
        
        // Log wall plane anchors
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                print("SimpleARSessionManager: Detected vertical plane: \(planeAnchor.identifier.uuidString)")
            }
        }
    }
    
    /// Called when the session was interrupted
    func sessionWasInterrupted(_ session: ARSession) {
        isSessionRunning = false
        print("SimpleARSessionManager: Session was interrupted")
    }
    
    /// Called when the session interruption ended
    func sessionInterruptionEnded(_ session: ARSession) {
        print("SimpleARSessionManager: Session interruption ended")
        
        // Restart session with appropriate options to retain anchor positions
        guard let arView = arView else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        arView.session.run(configuration, options: [])
        
        isSessionRunning = true
    }
    
    /// Called when the session fails with an error
    func session(_ session: ARSession, didFailWithError error: Error) {
        isSessionRunning = false
        
        print("SimpleARSessionManager: Session failed with error: \(error.localizedDescription)")
        
        // Handle specific error types
        if let arError = error as? ARError {
            switch arError.code {
            case .cameraUnauthorized:
                print("SimpleARSessionManager: Camera access is not authorized")
            case .worldTrackingFailed:
                // Try to recover by restarting
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.restartSession()
                }
            default:
                print("SimpleARSessionManager: AR error with code: \(arError.code.rawValue)")
            }
        }
    }
}
