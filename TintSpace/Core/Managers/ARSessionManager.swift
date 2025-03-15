//
//  ARSessionManager.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - Custom Notification Names
extension Notification.Name {
    // Custom notification names for AR events
    static let customARSessionWasInterrupted = Notification.Name("ARSessionWasInterrupted")
    static let customARSessionInterruptionEnded = Notification.Name("ARSessionInterruptionEnded")
    static let customARFrameDidUpdate = Notification.Name("ARFrameDidUpdate")
    static let customARTrackingStateChanged = Notification.Name("ARTrackingStateChanged")
    static let customARLightingEstimationUpdated = Notification.Name("ARLightingEstimationUpdated")
}

/// Manages the ARKit session and related functionality
class ARSessionManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Indicates if the AR session is currently running
    @Published var isSessionRunning = false
    
    /// Error message if session failed
    @Published var sessionErrorMessage: String?
    
    /// Current tracking state of the AR session
    @Published private(set) var trackingState: TrackingState = .initializing
    
    /// Current ambient light intensity, from 0 (dark) to 1 (bright)
    @Published private(set) var ambientIntensity: CGFloat = 0.0
    
    /// Current ambient light color temperature in Kelvin
    @Published private(set) var ambientColorTemperature: CGFloat = 6500.0
    
    // MARK: - Public Properties
    
    /// The ARView from RealityKit
    var arView: ARView?
    
    /// Whether AR world tracking is supported on this device
    var isWorldTrackingSupported: Bool {
        return ARWorldTrackingConfiguration.isSupported
    }
    
    /// Whether people occlusion is supported on this device
    var isPeopleOcclusionSupported: Bool {
        return ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
    }
    
    /// Whether scene reconstruction is supported on this device
    var isSceneReconstructionSupported: Bool {
        if #available(iOS 13.4, *) {
            return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        } else {
            return false
        }
    }
    
    /// Whether LiDAR is available on this device (inferred from scene reconstruction support)
    var isLidarSupported: Bool {
        return isSceneReconstructionSupported
    }
    
    // MARK: - Callback Properties
    
    /// Event handler for tracking state changes
    var onTrackingStateChanged: ((TrackingState) -> Void)?
    
    /// Event handler for lighting estimation updates
    var onLightingEstimationUpdated: (() -> Void)?
    
    /// Event handler for each frame update
    var onFrameUpdated: ((ARFrame) -> Void)?
    
    /// Event handler for anchors being added
    var onAnchorsAdded: (([ARAnchor]) -> Void)?
    
    /// Event handler for anchors being updated
    var onAnchorsUpdated: (([ARAnchor]) -> Void)?
    
    /// Event handler for anchors being removed
    var onAnchorsRemoved: (([ARAnchor]) -> Void)?
    
    // MARK: - Private Properties
    
    /// Default AR Configuration
    private var configuration: ARWorldTrackingConfiguration
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Tracking state enumeration for AR session
    enum TrackingState: Equatable {
        case initializing
        case normal
        case limited(reason: ARCamera.TrackingState.Reason)
        case notAvailable
        
        /// Whether tracking is limited or unavailable
        var isLimited: Bool {
            switch self {
            case .limited, .notAvailable:
                return true
            default:
                return false
            }
        }
        
        /// User-friendly description of tracking state
        var description: String {
            switch self {
            case .initializing:
                return "Initializing AR session..."
            case .normal:
                return "AR tracking normal"
            case .limited(let reason):
                switch reason {
                case .excessiveMotion:
                    return "Limited tracking: Please move the device more slowly"
                case .insufficientFeatures:
                    return "Limited tracking: Not enough surface details"
                case .initializing:
                    return "Limited tracking: Initializing"
                case .relocalizing:
                    return "Limited tracking: Relocalizing"
                @unknown default:
                    return "Limited tracking: Unknown reason"
                }
            case .notAvailable:
                return "Tracking not available"
            }
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        // Initialize stored properties first
        self.configuration = ARWorldTrackingConfiguration()
        
        // Call super.init() before accessing instance methods
        super.init()
        
        // Now it's safe to call instance methods
        setupConfiguration()
        
        LogManager.shared.info(message: "ARSessionManager initialized", category: "AR")
    }
    
    // MARK: - Configuration Methods
    
    /// Set up the initial AR configuration
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
        
        // Enable scene reconstruction (LiDAR) if available
        if #available(iOS 13.4, *) {
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
                LogManager.shared.info(message: "Scene reconstruction enabled", category: "AR")
            }
        }
    }
    
    /// Create an optimized configuration for wall detection
    /// - Returns: A configured ARWorldTrackingConfiguration
    func createWallDetectionConfiguration() -> ARWorldTrackingConfiguration {
        // Start with the basic configuration we already set up
        let config = configuration
        return config
    }
    
    // MARK: - Session Control Methods
    
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
            trackingState = .initializing
            
            LogManager.shared.success("AR session started successfully", category: "AR")
        }
    }
    
    /// Start the AR session with optimization for wall detection
    /// - Parameter resetTracking: Whether to reset the AR tracking
    func startWallDetectionSession(resetTracking: Bool = true) {
        guard let arView = arView else {
            sessionErrorMessage = "AR View not initialized"
            LogManager.shared.error("Failed to start AR session: AR View not initialized", category: "AR")
            return
        }
        
        // Ensure we're the delegate
        arView.session.delegate = self
        
        // Create optimized configuration
        let wallConfig = createWallDetectionConfiguration()
        
        // Set up session options
        var options: ARSession.RunOptions = []
        if resetTracking {
            options.insert(.resetTracking)
            options.insert(.removeExistingAnchors)
        }
        
        // Start performance measurement
        LogManager.shared.measure("AR Wall Detection Session Startup") {
            // Start AR session
            arView.session.run(wallConfig, options: options)
            isSessionRunning = true
            sessionErrorMessage = nil
            trackingState = .initializing
            
            LogManager.shared.success("AR wall detection session started successfully", category: "AR")
        }
    }
    
    /// Pauses the AR session
    func pauseSession() {
        arView?.session.pause()
        isSessionRunning = false
        LogManager.shared.info(message: "AR session paused", category: "AR")
    }
    
    /// Reconfigure the AR session with enhanced options
    /// - Parameter options: Additional options for the reconfiguration
    func reconfigureSession(options: ARSession.RunOptions = []) {
        guard isSessionRunning, let arView = arView else {
            LogManager.shared.warning("Cannot reconfigure: AR session not running or view not available", category: "AR")
            return
        }
        
        let configuration = createWallDetectionConfiguration()
        arView.session.run(configuration, options: options)
        
        LogManager.shared.info(message: "AR session reconfigured", category: "AR")
    }
    
    /// Restart the AR session
    func restartSession() {
        pauseSession()
        
        // Wait briefly before restarting to ensure clean state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startWallDetectionSession(resetTracking: true)
        }
    }
    
    // MARK: - Status and Information Methods
    
    /// Get detailed information about the current AR session
    /// - Returns: A dictionary with session information
    func getSessionInfo() -> [String: Any] {
        var info: [String: Any] = [:]
        
        info["isRunning"] = isSessionRunning
        info["trackingState"] = trackingState.description
        info["ambientIntensity"] = ambientIntensity
        info["ambientColorTemperature"] = ambientColorTemperature
        info["worldTrackingSupported"] = isWorldTrackingSupported
        info["peopleOcclusionSupported"] = isPeopleOcclusionSupported
        info["sceneReconstructionSupported"] = isSceneReconstructionSupported
        info["lidarSupported"] = isLidarSupported
        
        return info
    }
    
    /// Check if lighting conditions are sufficient for good AR experience
    /// - Returns: True if lighting is sufficient, false otherwise
    func isLightingSufficient() -> Bool {
        // Consider lighting sufficient if intensity is above 0.3 (30%)
        return ambientIntensity > 0.3
    }
    
    // MARK: - Frame Processing
    
    /// Process the updated frame to extract tracking state, lighting information, etc.
    /// - Parameter frame: The AR frame to process
    func processUpdatedFrame(_ frame: ARFrame) {
        // Update tracking state
        updateTrackingState(from: frame.camera)
        
        // Update lighting estimation
        updateLightingEstimation(from: frame)
        
        // Notify observers about the frame update
        onFrameUpdated?(frame)
        
        // Post frame update notification
        NotificationCenter.default.post(
            name: .customARFrameDidUpdate,
            object: self,
            userInfo: ["frame": frame]
        )
    }
    
    /// Update the tracking state based on camera information
    /// - Parameter camera: The AR camera
    private func updateTrackingState(from camera: ARCamera) {
        let oldState = trackingState
        
        switch camera.trackingState {
        case .normal:
            trackingState = .normal
        case .notAvailable:
            trackingState = .notAvailable
        case .limited(let reason):
            trackingState = .limited(reason: reason)
        }
        
        // Only notify if state actually changed
        if oldState != trackingState {
            onTrackingStateChanged?(trackingState)
            
            LogManager.shared.info(message: "Tracking state changed: \(trackingState.description)", category: "ARSession")
            
            // Post notification for subscribers
            NotificationCenter.default.post(
                name: .customARTrackingStateChanged,
                object: self,
                userInfo: ["trackingState": trackingState]
            )
        }
    }
    
    /// Update lighting estimation information from the frame
    /// - Parameter frame: The AR frame containing lighting information
    private func updateLightingEstimation(from frame: ARFrame) {
        // Check if we have lighting estimation
        guard let lightEstimate = frame.lightEstimate else { return }
        
        let oldIntensity = ambientIntensity
        let oldTemperature = ambientColorTemperature
        
        // Update ambient intensity
        ambientIntensity = CGFloat(lightEstimate.ambientIntensity / 1000.0)
        
        // Update color temperature
        ambientColorTemperature = CGFloat(lightEstimate.ambientColorTemperature)
        
        // Only notify if values changed significantly
        if abs(oldIntensity - ambientIntensity) > 0.1 || abs(oldTemperature - ambientColorTemperature) > 200 {
            onLightingEstimationUpdated?()
            
            // Post notification for subscribers
            NotificationCenter.default.post(
                name: .customARLightingEstimationUpdated,
                object: self,
                userInfo: nil
            )
        }
    }
}

// MARK: - ARSessionDelegate
extension ARSessionManager: ARSessionDelegate {
    // Add this property to store just the needed data from frames
    private struct FrameSnapshot {
        let camera: ARCamera
        let lightEstimate: ARLightEstimate?
        let anchors: [ARAnchor]
        let timestamp: TimeInterval
    }
    
    // Modify your session delegate method
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Create a snapshot with only the data we need
        let snapshot = extractFrameData(frame)
        
        // Process the snapshot, not the full frame
        processFrameSnapshot(snapshot)
        
        // Notify observers with the lightweight snapshot data
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.onFrameUpdated?(frame)
        }
    }
        
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        isSessionRunning = false
        sessionErrorMessage = "AR Session failed: \(error.localizedDescription)"
        LogManager.shared.error("AR session failed", category: "AR", error: error)
        
        // Handle specific error types
        if let arError = error as? ARError {
            switch arError.code {
            case .cameraUnauthorized:
                sessionErrorMessage = "Camera access is not authorized. Please allow camera access in Settings."
            case .worldTrackingFailed:
                // Try to recover by restarting the session
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.restartSession()
                }
            default:
                // For other errors, just log the code
                LogManager.shared.error("AR session failed with code: \(arError.code.rawValue)", category: "AR")
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        // Notify observers about added anchors
        onAnchorsAdded?(anchors)
        
        // Log wall plane anchors
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical {
                LogManager.shared.ar("Detected vertical plane: \(planeAnchor.identifier.uuidString)", category: "PlaneDetection")
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        // Notify observers about updated anchors
        onAnchorsUpdated?(anchors)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        // Notify observers about removed anchors
        onAnchorsRemoved?(anchors)
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        isSessionRunning = false
        
        LogManager.shared.warning("AR session was interrupted", category: "AR")
        
        // Post notification for subscribers
        NotificationCenter.default.post(
            name: .customARSessionWasInterrupted,
            object: self,
            userInfo: nil
        )
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        LogManager.shared.info(message: "AR session interruption ended", category: "AR")
        
        // Post notification for subscribers
        NotificationCenter.default.post(
            name: .customARSessionInterruptionEnded,
            object: self,
            userInfo: nil
        )
        
        // Restart session with appropriate options
        startWallDetectionSession(resetTracking: false)
    }
    
    // Extract only the data we need from the frame
    private func extractFrameData(_ frame: ARFrame) -> FrameSnapshot {
        return FrameSnapshot(
            camera: frame.camera,
            lightEstimate: frame.lightEstimate,
            anchors: frame.anchors,
            timestamp: frame.timestamp
        )
    }
    
    // Process the snapshot instead of the full frame
    private func processFrameSnapshot(_ snapshot: FrameSnapshot) {
        // Update tracking state
        updateTrackingState(from: snapshot.camera)
        
        // Update lighting estimation
        if let lightEstimate = snapshot.lightEstimate {
            updateLightingEstimation(lightEstimate)
        }
        
        // Post notification with needed data only
        NotificationCenter.default.post(
            name: .customARFrameDidUpdate,
            object: self,
            userInfo: ["anchors": snapshot.anchors, "timestamp": snapshot.timestamp]
        )
    }
    
    // Update to work with lightEstimate directly
    private func updateLightingEstimation(_ lightEstimate: ARLightEstimate) {
        // Update ambient intensity
        ambientIntensity = CGFloat(lightEstimate.ambientIntensity / 1000.0)
        
        // Update color temperature
        ambientColorTemperature = CGFloat(lightEstimate.ambientColorTemperature)
        
        // Only notify if values changed significantly
        if significantLightingChange() {
            onLightingEstimationUpdated?()
            
            // Post notification
            NotificationCenter.default.post(
                name: .customARLightingEstimationUpdated,
                object: self,
                userInfo: nil
            )
        }
    }
    
    private func significantLightingChange() -> Bool {
        // Implementation based on your needs
        return true
    }
}
