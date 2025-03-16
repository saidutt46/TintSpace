//
//  ARSessionManager.swift
//  TintSpace
//
//  Updated for TintSpace on 3/16/25.
//

import Foundation
import ARKit
import RealityKit
import Combine
import AVFoundation

/// Manages the ARKit session and related functionality
class ARSessionManager: NSObject, ARSessionDelegate, ObservableObject {
    // MARK: - Properties
    
    /// Delegate to receive AR session events
    weak var delegate: ARSessionManagerDelegate?
    
    /// Current state of the AR wall painting experience
    @Published private(set) var currentState: ARWallPaintingState = .initializing {
        didSet {
            // Notify delegate of state changes
            delegate?.arSessionManager(self, didChangeState: currentState)
            
            // Log state changes
            LogManager.shared.info(message: "AR session state changed: \(String(describing: currentState))", category: "AR")
        }
    }
    
    /// The ARView from RealityKit
    weak var arView: ARView? {
        didSet {
            // Set the scene in the wall entity manager when ARView changes
            if let scene = arView?.scene {
                wallEntityManager.setScene(scene)
            }
        }
    }
    
    /// Wall entity manager for tracking detected walls
    let wallEntityManager: WallEntityManager
    
    /// Callback for when the AR session is initialized
    var onARSessionInitialized: (() -> Void)?
    
    /// Whether the AR session is running
    private(set) var isSessionRunning = false
    
    /// Error message if session fails
    private(set) var sessionErrorMessage: String?
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Message manager for user feedback
    var messageManager: ARMessageManager?
    
    // MARK: - Initialization
    
    init(wallEntityManager: WallEntityManager = WallEntityManager()) {
        self.wallEntityManager = wallEntityManager
        super.init()
        
        // Set up Combine subscriptions for wall entity events
        setupSubscriptions()
    }
    
    // MARK: - Private Methods
    
    /// Set up Combine subscriptions for wall entity events
    private func setupSubscriptions() {
        // Listen for wall detection events
        wallEntityManager.wallDetectedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] wall in
                guard let self = self else { return }
                
                // Update state if needed
                if self.currentState == .scanning {
                    self.currentState = .wallsDetected
                }
                
                // Notify user via message manager
                self.messageManager?.showMessage(
                    "Wall detected!",
                    duration: 2.0,
                    position: .center,
                    icon: "checkmark.circle",
                    isImmediate: false
                )
            }
            .store(in: &cancellables)
        
        // Listen for wall selection events
        wallEntityManager.wallSelectedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] wall in
                guard let self = self else { return }
                
                // Update state based on wall selection
                if let _ = wall {
                    self.currentState = .wallSelected
                    
                    // Notify user via message manager
                    self.messageManager?.showMessage(
                        "Wall selected! Choose a color to apply.",
                        duration: 2.0,
                        position: .bottom,
                        icon: "hand.tap",
                        isImmediate: false
                    )
                } else if self.wallEntityManager.walls.isEmpty {
                    self.currentState = .scanning
                } else {
                    self.currentState = .wallsDetected
                }
            }
            .store(in: &cancellables)
    }
    
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
            let error = NSError(domain: "ARSessionManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AR View not initialized"])
            handleError(error)
            return
        }
        
        // Update state to initializing
        currentState = .initializing
        
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
                    
                    // Update state to scanning
                    self.currentState = .scanning
                    
                    self.messageManager?.showMessage(
                        "AR Ready! 🏠\nScan your space to detect walls.",
                        duration: 3.0,
                        position: .center,
                        icon: "arkit",
                        isImmediate: true
                    )
                }
            } else {
                let error = NSError(domain: "ARSessionManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Camera access is required for AR"])
                self.handleError(error)
            }
        }
    }
    
    /// Pause the AR session
    func pauseSession() {
        arView?.session.pause()
        isSessionRunning = false
        currentState = .paused
        LogManager.shared.info(message: "AR session paused", category: "AR")
    }
    
    /// Restart the AR session
    func restartSession() {
        pauseSession()
        
        // Clear all wall entities
        for wallID in wallEntityManager.walls.keys {
            wallEntityManager.removeWall(withID: wallID)
        }
        
        // Wait briefly before restarting to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSession()
        }
    }
    
    // MARK: - Error Handling
    
    /// Handle errors in the AR session
    private func handleError(_ error: Error) {
        isSessionRunning = false
        sessionErrorMessage = error.localizedDescription
        currentState = .failed(error)
        
        LogManager.shared.error("AR session error: \(error.localizedDescription)", category: "AR", error: error)
        
        // Notify the user via message manager
        messageManager?.showMessage(
            "AR session error: \(error.localizedDescription)",
            duration: 5.0,
            position: .center,
            icon: "exclamationmark.triangle"
        )
        
        // Notify delegate
        delegate?.arSessionManager(self, didEncounterError: error)
    }
    
    // MARK: - ARSessionDelegate Methods
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        handleError(error)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        isSessionRunning = false
        currentState = .paused
        LogManager.shared.warning("AR session was interrupted", category: "AR")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        LogManager.shared.info(message: "AR session interruption ended", category: "AR")
        startSession()
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            // If we were in a limited state before, update to scanning or wallsDetected
            if case .limited = currentState {
                currentState = wallEntityManager.walls.isEmpty ? .scanning : .wallsDetected
            }
        case .notAvailable:
            LogManager.shared.warning("AR tracking not available", category: "AR")
        case .limited(let reason):
            currentState = .limited(reason)
            LogManager.shared.warning("AR tracking limited: \(reason)", category: "AR")
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                // Create and register a new wall entity
                let wall = wallEntityManager.createAndRegisterWall(from: planeAnchor)
                
                // If this is the first wall detected, update state
                if currentState == .scanning {
                    currentState = .wallsDetected
                }
                
                // Notify delegate
                delegate?.arSessionManager(self, didDetectWall: planeAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                // Update the wall entity with the new anchor
                wallEntityManager.updateWall(with: planeAnchor)
                
                // Notify delegate
                delegate?.arSessionManager(self, didUpdateWall: planeAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                // Remove the wall entity
                wallEntityManager.removeWall(withID: planeAnchor.identifier)
                
                // Notify delegate
                delegate?.arSessionManager(self, didRemoveWall: planeAnchor)
                
                // If all walls are gone, update state
                if wallEntityManager.walls.isEmpty && (currentState == .wallsDetected || currentState == .wallSelected) {
                    currentState = .scanning
                }
            }
        }
    }
}
