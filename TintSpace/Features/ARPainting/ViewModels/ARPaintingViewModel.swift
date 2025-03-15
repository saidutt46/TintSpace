//
//  ARPaintingViewModel.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import Foundation
import ARKit
import RealityKit
import Combine
import SwiftUI

/// Status message type for ARPaintingView
enum ARStatusMessageType {
    case info
    case success
    case warning
    case error
}

/// View-specific status message model to avoid conflicts with StatusNotificationManager
struct ARViewStatusMessage: Identifiable {
    let id = UUID()
    let text: String
    let type: ARStatusMessageType
    let duration: TimeInterval
    let timestamp = Date()
    
    /// Icon for the message type
    var icon: String {
        switch type {
        case .info:
            return "info.circle"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }
}

/// Create a protocol class to handle UIGestureRecognizerDelegate
class GestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only handle taps in the AR view, not on UI elements
        // This is just a safety check, as SwiftUI handles most of this
        return true
    }
}

/// ViewModel for the ARPaintingView
class ARPaintingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current status message to display
    @Published var currentStatusMessage: ARViewStatusMessage?
    
    /// List of detected walls
    @Published var detectedWalls: [WallPlane] = []
    
    /// Currently selected wall
    @Published var selectedWall: WallPlane?
    
    /// Whether wall detection is active
    @Published var isDetectingWalls = false
    
    /// Whether tracking is limited
    @Published var isTrackingLimited = false
    
    /// AR session information for the info panel
    @Published var sessionInfo: [String: Any] = [:]
    
    // MARK: - Private Properties
    
    /// The AR session manager
    private let arSessionManager: ARSessionManager
    
    /// The wall detection service
    private var wallDetectionService: WallDetectionServiceProtocol
    
    /// Reference to the AR view
    private var arView: ARView?
    
    /// Status message queue
    private var pendingStatusMessages: [ARViewStatusMessage] = []
    
    /// Active status message timers
    private var statusMessageTimer: Timer?
    
    /// Gesture delegate for handling UI gestures
    private var gestureDelegate = GestureDelegate()
    
    /// AnyCancellable storage
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize with required services
    /// - Parameters:
    ///   - arSessionManager: The AR session manager
    ///   - wallDetectionService: The wall detection service
    init(arSessionManager: ARSessionManager, wallDetectionService: WallDetectionServiceProtocol) {
        self.arSessionManager = arSessionManager
        self.wallDetectionService = wallDetectionService
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Set up the AR view
    /// - Parameter arView: The AR view to configure
    func setupARView(_ arView: ARView) {
        self.arView = arView
        
        // Configure AR view with session manager
        self.arSessionManager.arView = arView
        
        // Add tap gesture recognizer
        let tapRecognizer = UITapGestureRecognizer(target: self, action: nil)
        tapRecognizer.delegate = gestureDelegate
        arView.addGestureRecognizer(tapRecognizer)
        
        LogManager.shared.info(message: "AR view configured", category: "ARView")
    }
    
    /// Start the AR session
    func startARSession() {
        LogManager.shared.info(message: "Starting AR session", category: "ARViewModel")
        
        // Start AR session with wall detection configuration
        arSessionManager.startWallDetectionSession(resetTracking: true)
        
        // Start wall detection service
        wallDetectionService.startWallDetection()
        isDetectingWalls = true
        
        // Show initial status message
        showStatusMessage(
            text: "Move around to detect walls",
            type: .info,
            duration: 3.0
        )
    }
    
    /// Pause the AR session
    func pauseARSession() {
        LogManager.shared.info(message: "Pausing AR session", category: "ARViewModel")
        
        // Pause AR session
        arSessionManager.pauseSession()
        
        // Stop wall detection service
        wallDetectionService.stopWallDetection()
        isDetectingWalls = false
    }
    
    /// Reset the AR session
    func resetSession() {
        LogManager.shared.info(message: "Resetting AR session", category: "ARViewModel")
        
        // Show status message
        showStatusMessage(
            text: "Resetting AR session...",
            type: .info,
            duration: 2.0
        )
        
        // Clear all detected walls
        wallDetectionService.clearWalls()
        
        // Update published properties
        updateDetectedWalls([])
        selectedWall = nil
        
        // Restart AR session
        arSessionManager.restartSession()
        
        // Start wall detection again
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.wallDetectionService.startWallDetection()
            self.isDetectingWalls = true
        }
    }
    
    /// Handle tap events on the AR view
    /// - Parameter location: The screen location of the tap
    func handleTap(at location: CGPoint) {
        guard let arView = arView else { return }
        
        // Perform hit testing to find walls
        let hitTestResults = arView.hitTest(location, types: .estimatedVerticalPlane)
        
        // Find hit test results that correspond to our detected walls
        if let firstResult = hitTestResults.first,
           let planeAnchor = firstResult.anchor as? ARPlaneAnchor,
           let wallID = wallDetectionService.detectedWalls.first(where: { $0.anchor.identifier == planeAnchor.identifier })?.id {
            
            // Wall was tapped, select it
            wallDetectionService.selectWall(withID: wallID)
            
            // Show status message
            showStatusMessage(
                text: "Wall selected",
                type: .success,
                duration: 1.5
            )
            
            LogManager.shared.userAction("WallTapped", details: ["wallID": wallID.uuidString])
        } else {
            // Check for direct entity hit test
            let entityHitResults = arView.hitTest(location)
            
            if let firstEntityHit = entityHitResults.first,
               let modelEntity = firstEntityHit.entity as? ModelEntity,
               let hitWall = wallDetectionService.detectedWalls.first(where: { wall in
                   let wallEntity = wallDetectionService.getOrCreateVisualEntity(for: wall)
                   return wallEntity == modelEntity
               }) {
                
                // Wall entity was tapped, select it
                wallDetectionService.selectWall(withID: hitWall.id)
                
                // Show status message
                showStatusMessage(
                    text: "Wall selected",
                    type: .success,
                    duration: 1.5
                )
                
                LogManager.shared.userAction("WallEntityTapped", details: ["wallID": hitWall.id.uuidString])
            } else {
                // No wall was tapped, deselect the current wall
                if selectedWall != nil {
                    wallDetectionService.deselectWall()
                    
                    // Show status message
                    showStatusMessage(
                        text: "Wall deselected",
                        type: .info,
                        duration: 1.5
                    )
                    
                    LogManager.shared.userAction("WallDeselected")
                } else {
                    // No wall was selected previously
                    showStatusMessage(
                        text: "No wall detected at this location",
                        type: .info,
                        duration: 1.5
                    )
                    
                    LogManager.shared.userAction("TappedNonWallArea")
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Set up observers for AR session and wall detection events
    private func setupObservers() {
        // Observe AR session tracking state changes
        arSessionManager.onTrackingStateChanged = { [weak self] trackingState in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Update tracking limited status
                self.isTrackingLimited = trackingState.isLimited
                
                // Update session info
                self.updateSessionInfo()
                
                // Show appropriate messages based on tracking state
                switch trackingState {
                case .initializing:
                    self.showStatusMessage(
                        text: "Initializing AR session...",
                        type: .info,
                        duration: 2.0
                    )
                case .normal:
                    if self.isTrackingLimited {
                        self.showStatusMessage(
                            text: "AR tracking restored",
                            type: .success,
                            duration: 2.0
                        )
                    }
                case .limited(let reason):
                    switch reason {
                    case .excessiveMotion:
                        self.showStatusMessage(
                            text: "Move the device more slowly",
                            type: .warning,
                            duration: 3.0
                        )
                    case .insufficientFeatures:
                        self.showStatusMessage(
                            text: "Not enough features in the environment",
                            type: .warning,
                            duration: 3.0
                        )
                    case .initializing:
                        self.showStatusMessage(
                            text: "Initializing tracking...",
                            type: .info,
                            duration: 2.0
                        )
                    case .relocalizing:
                        self.showStatusMessage(
                            text: "Relocalizing...",
                            type: .info,
                            duration: 2.0
                        )
                    @unknown default:
                        self.showStatusMessage(
                            text: "Limited tracking for unknown reason",
                            type: .warning,
                            duration: 3.0
                        )
                    }
                case .notAvailable:
                    self.showStatusMessage(
                        text: "AR tracking not available",
                        type: .error,
                        duration: 3.0
                    )
                }
            }
        }
        
        // Observe lighting estimation updates
        arSessionManager.onLightingEstimationUpdated = { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.updateSessionInfo()
                
                // Check if lighting is sufficient
                if !self.arSessionManager.isLightingSufficient() {
                    self.showStatusMessage(
                        text: "Low light detected, move to a brighter area",
                        type: .warning,
                        duration: 3.0
                    )
                }
            }
        }
        
        // Observe frame updates
        arSessionManager.onFrameUpdated = { [weak self] frame in
            guard let self = self else { return }
            
            // Process frame in the wall detection service
            self.wallDetectionService.processFrame(frame)
        }
        
        // Observe wall detection events
        wallDetectionService.onWallDetected = { [weak self] wall in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                var updatedWalls = self.detectedWalls
                updatedWalls.append(wall)
                self.updateDetectedWalls(updatedWalls)
                
                // Show status message for the first wall
                if self.detectedWalls.count == 1 {
                    self.showStatusMessage(
                        text: "Wall detected! Tap to select it",
                        type: .success,
                        duration: 3.0
                    )
                } else if self.detectedWalls.count == 3 {
                    // Show a helpful message after a few walls
                    self.showStatusMessage(
                        text: "Multiple walls detected",
                        type: .success,
                        duration: 2.0
                    )
                }
                
                // Add the wall entity to the AR scene
                self.addWallEntityToScene(wall)
            }
        }
        
        wallDetectionService.onWallUpdated = { [weak self] wall in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Update the wall in our tracked walls
                var updatedWalls = self.detectedWalls
                if let index = updatedWalls.firstIndex(where: { $0.id == wall.id }) {
                    updatedWalls[index] = wall
                }
                self.updateDetectedWalls(updatedWalls)
                
                // Update selected wall if this is the selected one
                if wall.id == self.selectedWall?.id {
                    self.selectedWall = wall
                }
                
                // Update the wall entity in the scene
                self.updateWallEntityInScene(wall)
            }
        }
        
        wallDetectionService.onWallRemoved = { [weak self] wallID in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Remove the wall from our tracked walls
                let updatedWalls = self.detectedWalls.filter { $0.id != wallID }
                self.updateDetectedWalls(updatedWalls)
                
                // If the removed wall was selected, clear selection
                if self.selectedWall?.id == wallID {
                    self.selectedWall = nil
                }
                
                // Remove the wall entity from the scene
                self.removeWallEntityFromScene(withID: wallID)
            }
        }
    }
    
    /// Update the list of detected walls
    /// - Parameter walls: The updated wall list
    private func updateDetectedWalls(_ walls: [WallPlane]) {
        detectedWalls = walls
        updateSessionInfo()
    }
    
    /// Update the session info dictionary
    private func updateSessionInfo() {
        // Get session info from AR session manager
        sessionInfo = arSessionManager.getSessionInfo()
        
        // Add wall detection info
        sessionInfo["detectedWallCount"] = detectedWalls.count
    }
    
    /// Show a status message
    /// - Parameters:
    ///   - text: The message text
    ///   - type: The message type
    ///   - duration: The duration to show the message
    private func showStatusMessage(text: String, type: ARStatusMessageType, duration: TimeInterval) {
        // Create the message
        let message = ARViewStatusMessage(text: text, type: type, duration: duration)
        
        // Cancel any current timer
        statusMessageTimer?.invalidate()
        
        // Add to queue or display immediately
        if currentStatusMessage != nil {
            pendingStatusMessages.append(message)
        } else {
            displayStatusMessage(message)
        }
    }
    
    /// Display a status message and set up its timer
    /// - Parameter message: The message to display
    private func displayStatusMessage(_ message: ARViewStatusMessage) {
        DispatchQueue.main.async {
            self.currentStatusMessage = message
            
            // Set timer to clear the message
            self.statusMessageTimer = Timer.scheduledTimer(withTimeInterval: message.duration, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.currentStatusMessage = nil
                    self.statusMessageTimer = nil
                    
                    // Display next message if any
                    if let nextMessage = self.pendingStatusMessages.first {
                        self.pendingStatusMessages.removeFirst()
                        self.displayStatusMessage(nextMessage)
                    }
                }
            }
        }
    }
    
    /// Add a wall entity to the AR scene
    /// - Parameter wall: The wall to add
    private func addWallEntityToScene(_ wall: WallPlane) {
        // Ensure we're on the main thread for RealityKit operations
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.addWallEntityToScene(wall)
            }
            return
        }
        
        guard let arView = arView else { return }
        
        // Get or create the visual entity for the wall
        let wallEntity = wallDetectionService.getOrCreateVisualEntity(for: wall)
        
        // Add to scene if not already added
        if wallEntity.parent == nil {
            let anchorEntity = AnchorEntity(world: .zero)
            arView.scene.addAnchor(anchorEntity)
            anchorEntity.addChild(wallEntity)
        }
    }
    
    /// Update a wall entity in the AR scene
    /// - Parameter wall: The wall to update
    private func updateWallEntityInScene(_ wall: WallPlane) {
        // Ensure we're on the main thread for RealityKit operations
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateWallEntityInScene(wall)
            }
            return
        }
        
        // The wall detection service handles the entity updates
        _ = wallDetectionService.getOrCreateVisualEntity(for: wall)
    }
    
    /// Remove a wall entity from the AR scene
    /// - Parameter wallID: The ID of the wall to remove
    private func removeWallEntityFromScene(withID wallID: UUID) {
        // Ensure we're on the main thread for RealityKit operations
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.removeWallEntityFromScene(withID: wallID)
            }
            return
        }
        
        // Find the wall entity and remove it
        guard let arView = arView else { return }
        
        // Find and remove entity
        arView.scene.anchors.forEach { anchor in
            anchor.children.forEach { entity in
                if let modelEntity = entity as? ModelEntity,
                   let wall = detectedWalls.first(where: {
                       wallDetectionService.getOrCreateVisualEntity(for: $0) == modelEntity
                   }),
                   wall.id == wallID {
                    modelEntity.removeFromParent()
                }
            }
        }
    }
}
