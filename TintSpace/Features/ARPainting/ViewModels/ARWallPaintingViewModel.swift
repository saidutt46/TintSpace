//
//  ARWallPaintingViewModel.swift
//  TintSpace
//
//  Updated for TintSpace on 3/16/25.
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
    
    /// Currently selected wall ID
    @Published private(set) var selectedWallID: UUID?
    
    /// Loading state for the AR view
    @Published var isLoading = true
    
    /// Message manager for user feedback
    @Published var messageManager = ARMessageManager()
    
    @Published var detectedWallCount: Int = 0
    
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
        
        setupSubscriptions()
    }
    
    // MARK: - Setup Methods
    
    /// Set up subscriptions to wall entity events
    private func setupSubscriptions() {
        // Subscribe to wall selection events
        arSessionManager.wallEntityManager.wallSelectedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] wall in
                self?.selectedWallID = wall?.id
            }
            .store(in: &cancellables)
        
        // Subscribe to wall collection changes
        arSessionManager.wallEntityManager.wallDetectedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWallCount()
            }
            .store(in: &cancellables)

        arSessionManager.wallEntityManager.wallRemovedPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateWallCount()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - AR Setup
    
    /// Set up the AR view and configure the session manager
    func setupARView(_ arView: ARView) {
        self.arView = arView
        arSessionManager.arView = arView
        
        // Add tap gesture recognizer
        setupTapGesture(in: arView)
        
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
    
    /// Set up tap gesture for wall selection
    private func setupTapGesture(in arView: ARView) {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }
    
    /// Handle tap on AR view
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView = arView else { return }
        
        // Get the location of the tap in the AR view
        let location = gesture.location(in: arView)
        
        // Perform ray cast to detect wall
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .vertical)
        
        if let firstResult = results.first {
            if let planeAnchor = firstResult.anchor as? ARPlaneAnchor {
                // Get the wall entity and select it
                if let wall = arSessionManager.wallEntityManager.getWall(withID: planeAnchor.identifier) {
                    arSessionManager.wallEntityManager.selectWall(wall)
                    
                    // Provide haptic feedback
                    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                    feedbackGenerator.prepare()
                    feedbackGenerator.impactOccurred()
                    
                    LogManager.shared.info(message: "User tapped and selected wall \(planeAnchor.identifier)", category: "ARViewModel")
                }
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
        selectedWallID = nil
        arSessionManager.restartSession()
    }
    
    // MARK: - Wall Actions
    
    /// Apply a color to the selected wall
    /// - Parameter color: The color to apply
    func applyColorToSelectedWall(_ color: UIColor) {
        if arSessionManager.wallEntityManager.applyColorToSelectedWall(color) {
            // Update state
            currentARState = .colorApplied
            
            // Show feedback
            messageManager.showMessage(
                "Color applied!",
                duration: 2.0,
                position: .bottom,
                icon: "paintbrush.fill",
                isImmediate: false
            )
        }
    }
    
    /// Set the paint finish for the selected wall
    /// - Parameter finish: The paint finish to apply
    func setPaintFinishForSelectedWall(_ finish: WallEntity.PaintFinish) {
        if let selectedWall = getSelectedWall() {
            selectedWall.setPaintFinish(finish)
            
            // Update visualization
            selectedWall.updateVisualization()
            
            // Show feedback
            messageManager.showMessage(
                "Applied \(String(describing: finish)) finish",
                duration: 2.0,
                position: .bottom,
                icon: "paintpalette",
                isImmediate: false
            )
        }
    }
    
    /// Get the currently selected wall entity
    /// - Returns: The selected wall entity if any
    func getSelectedWall() -> WallEntity? {
        return selectedWallID.flatMap { arSessionManager.wallEntityManager.getWall(withID: $0) }
    }
    
    /// Clear the current wall selection
    func clearWallSelection() {
        arSessionManager.wallEntityManager.clearSelection()
    }
    
    // MARK: - UI Actions
    
    /// Show help information
    func showHelp() {
        LogManager.shared.info(message: "Help action triggered", category: "UI")
        messageManager.showMessage(
            "Tap on any detected wall to select it.\nThen choose a color to apply.",
            duration: 4.0,
            position: .center,
            icon: "info.circle",
            isImmediate: true
        )
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
            // Update UI state
            self.hasDetectedWalls = true
            
//            LogManager.shared.info(message: "ViewModel received wall detection: \(anchor.identifier)", category: "ARViewModel")
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
    
    private func updateWallCount() {
        detectedWallCount = arSessionManager.wallEntityManager.walls.count
    }
}
