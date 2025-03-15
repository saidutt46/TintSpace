//
//  WallDetectionService.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import Foundation
import ARKit
import RealityKit
import Combine

/// Protocol defining the wall detection service capabilities
protocol WallDetectionServiceProtocol {
    /// Current detected walls
    var detectedWalls: [WallPlane] { get }
    
    /// Wall detection events
    var onWallDetected: ((WallPlane) -> Void)? { get set }
    var onWallUpdated: ((WallPlane) -> Void)? { get set }
    var onWallRemoved: ((UUID) -> Void)? { get set }
    
    /// Select a wall for painting
    func selectWall(withID id: UUID)
    func deselectWall()
    var selectedWall: WallPlane? { get }
    
    /// Start/stop detection
    func startWallDetection()
    func stopWallDetection()
    
    /// Process ARKit frame updates
    func processFrame(_ frame: ARFrame)
    
    /// Get visual entity for a wall
    func getOrCreateVisualEntity(for wall: WallPlane) -> ModelEntity
    
    /// Clear all walls (e.g., when restarting session)
    func clearWalls()
}

/// Service responsible for detecting, tracking and managing walls in AR space
final class WallDetectionService: WallDetectionServiceProtocol {
    // MARK: - Private Properties
    
    /// ARSession manager to coordinate with
    private weak var arSessionManager: ARSessionManager?
    
    /// Dictionary to store detected walls by their ID
    private var wallsById: [UUID: WallPlane] = [:]
    
    /// Dictionary to map ARPlaneAnchor identifiers to our wall IDs
    private var anchorIDToWallID: [UUID: UUID] = [:]
    
    /// Dictionary to track visual entities for each wall
    private var wallVisualEntities: [UUID: ModelEntity] = [:]
    
    /// Currently selected wall ID
    private var selectedWallID: UUID?
    
    /// Queue for wall processing operations
    private let wallProcessingQueue = DispatchQueue(label: "com.tintspace.wallProcessingQueue", qos: .userInitiated)
    
    /// Cancellable storage for subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Confidence threshold for wall detection
    private let confidenceThreshold: Float
    
    /// Maximum distance for wall detection (in meters)
    private let maxWallDistance: Float
    
    /// Timer for throttling updates
    private var updateThrottleTimer: Timer?
    
    /// Minimum size for walls to be considered valid (in meters)
    private let minWallSize: Float
    
    // MARK: - Public Properties
    
    /// Current detected walls, computed to maintain consistent API
    var detectedWalls: [WallPlane] {
        Array(wallsById.values)
    }
    
    /// Callbacks for wall detection events
    var onWallDetected: ((WallPlane) -> Void)?
    var onWallUpdated: ((WallPlane) -> Void)?
    var onWallRemoved: ((UUID) -> Void)?
    
    /// Currently selected wall
    var selectedWall: WallPlane? {
        guard let selectedWallID = selectedWallID else { return nil }
        return wallsById[selectedWallID]
    }
    
    // MARK: - Initialization
    
    /// Initialize the wall detection service
    /// - Parameters:
    ///   - arSessionManager: The AR session manager to coordinate with
    ///   - confidenceThreshold: Threshold for wall detection confidence (0.0-1.0)
    ///   - maxWallDistance: Maximum distance for wall detection in meters
    ///   - minWallSize: Minimum size for walls in meters
    init(
        arSessionManager: ARSessionManager,
        confidenceThreshold: Float = Constants.AR.wallDetectionConfidenceThreshold,
        maxWallDistance: Float = Constants.AR.maxWallDistance,
        minWallSize: Float = 0.5
    ) {
        self.arSessionManager = arSessionManager
        self.confidenceThreshold = confidenceThreshold
        self.maxWallDistance = maxWallDistance
        self.minWallSize = minWallSize
        
        LogManager.shared.info(message: "WallDetectionService initialized", category: "WallDetection")
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /// Start wall detection process
    func startWallDetection() {
        LogManager.shared.info(message: "Starting wall detection", category: "WallDetection")
        
        // Nothing to do explicitly here as the processing happens
        // when ARSessionManager provides frames
    }
    
    /// Stop wall detection process
    func stopWallDetection() {
        LogManager.shared.info(message: "Stopping wall detection", category: "WallDetection")
        
        // Cancel any pending updates
        updateThrottleTimer?.invalidate()
        updateThrottleTimer = nil
    }
    
    /// Select a wall for painting
    /// - Parameter id: The ID of the wall to select
    func selectWall(withID id: UUID) {
        wallProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Deselect the currently selected wall if any
            if let currentSelectedID = self.selectedWallID, var currentWall = self.wallsById[currentSelectedID] {
                currentWall.isSelected = false
                self.wallsById[currentSelectedID] = currentWall
                
                // Update visual entity for previously selected wall
                if let entity = self.wallVisualEntities[currentSelectedID] {
                    self.updateWallVisualEntity(entity, forWall: currentWall, isSelected: false)
                }
                
                // Notify that the wall was updated (deselected)
                DispatchQueue.main.async {
                    self.onWallUpdated?(currentWall)
                }
            }
            
            // Select the new wall if it exists
            if var targetWall = self.wallsById[id] {
                targetWall.isSelected = true
                self.wallsById[id] = targetWall
                self.selectedWallID = id
                
                // Update visual entity for newly selected wall
                if let entity = self.wallVisualEntities[id] {
                    self.updateWallVisualEntity(entity, forWall: targetWall, isSelected: true)
                }
                
                // Notify that the wall was updated (selected)
                DispatchQueue.main.async {
                    self.onWallUpdated?(targetWall)
                }
                
                LogManager.shared.info(message: "Wall selected: \(id.uuidString)", category: "WallDetection")
            } else {
                LogManager.shared.warning("Attempted to select nonexistent wall: \(id.uuidString)", category: "WallDetection")
            }
        }
    }
    
    /// Deselect the currently selected wall
    func deselectWall() {
        guard let selectedWallID = selectedWallID else { return }
        
        wallProcessingQueue.async { [weak self] in
            guard let self = self, var wall = self.wallsById[selectedWallID] else { return }
            
            wall.isSelected = false
            self.wallsById[selectedWallID] = wall
            self.selectedWallID = nil
            
            // Update visual entity
            if let entity = self.wallVisualEntities[selectedWallID] {
                self.updateWallVisualEntity(entity, forWall: wall, isSelected: false)
            }
            
            // Notify that the wall was updated (deselected)
            DispatchQueue.main.async {
                self.onWallUpdated?(wall)
            }
            
            LogManager.shared.info(message: "Wall deselected: \(selectedWallID.uuidString)", category: "WallDetection")
        }
    }
    
    /// Process ARKit frame to detect and update walls
    /// - Parameter frame: The ARFrame to process
    func processFrame(_ frame: ARFrame) {
        // Skip processing if session is not running
        guard arSessionManager?.isSessionRunning == true else { return }
        
        // Throttle updates to avoid too frequent processing
        // We don't need to process every single frame for wall detection
        if updateThrottleTimer == nil {
            updateThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
                self?.updateThrottleTimer = nil
                
                // Process frame on background queue
                self?.wallProcessingQueue.async {
                    self?.processPlaneAnchors(in: frame)
                }
            }
        }
    }
    
    /// Get or create a visual entity for a wall
    /// - Parameter wall: The wall to create or get a visual entity for
    /// - Returns: A ModelEntity representing the wall
    func getOrCreateVisualEntity(for wall: WallPlane) -> ModelEntity {
        // Ensure we're on the main thread for RealityKit operations
        if !Thread.isMainThread {
            var result: ModelEntity?
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                result = self.getOrCreateVisualEntity(for: wall)
                semaphore.signal()
            }
            
            semaphore.wait()
            return result!
        }
        
        if let existingEntity = wallVisualEntities[wall.id] {
            return existingEntity
        }
        
        // Create a new entity
        let entity = createWallEntity(for: wall)
        wallVisualEntities[wall.id] = entity
        
        // Update selection state
        updateWallVisualEntity(entity, forWall: wall, isSelected: wall.isSelected)
        
        return entity
    }
    
    /// Clear all wall data (e.g., when resetting AR session)
    func clearWalls() {
        wallProcessingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Copy wall IDs to avoid modification during iteration
            let wallIDs = Set(self.wallsById.keys)
            
            // Notify about removed walls
            DispatchQueue.main.async {
                for wallID in wallIDs {
                    self.onWallRemoved?(wallID)
                }
            }
            
            // Clear all wall data
            self.wallsById.removeAll()
            self.anchorIDToWallID.removeAll()
            self.wallVisualEntities.removeAll()
            self.selectedWallID = nil
            
            LogManager.shared.info(message: "All walls cleared", category: "WallDetection")
        }
    }
    
    // MARK: - Private Methods
    
    /// Set up observers for AR session events
    private func setupObservers() {
        guard arSessionManager != nil else {
            LogManager.shared.error("Cannot setup observers: ARSessionManager is nil", category: "WallDetection")
            return
        }
        
        // Observe session interruptions to handle wall tracking resumption
        NotificationCenter.default
            .publisher(for: .customARSessionWasInterrupted)
            .sink { [weak self] _ in
                LogManager.shared.warning("AR session interrupted, wall detection paused", category: "WallDetection")
                self?.stopWallDetection()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .publisher(for: .customARSessionInterruptionEnded)
            .sink { [weak self] _ in
                LogManager.shared.info(message: "AR session interruption ended, resuming wall detection", category: "WallDetection")
                self?.startWallDetection()
            }
            .store(in: &cancellables)
    }
    
    /// Process plane anchors in the AR frame
    /// - Parameter frame: The AR frame containing plane anchors
    private func processPlaneAnchors(in frame: ARFrame) {
        guard let anchors = frame.anchors as? [ARAnchor] else { return }
        
        // Track valid plane anchors and existing walls to detect removals
        var validAnchorIDs = Set<UUID>()
        
        for anchor in anchors {
            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
            
            // Only consider vertical planes (walls)
            guard planeAnchor.alignment == .vertical else { continue }
            
            // For now, we'll skip this confidence check since
            // the ARPlaneAnchor doesn't have a direct confidence property
            // We'll rely on size and distance checks instead
            
            // Skip planes that are too small
            guard planeAnchor.planeExtent.width >= minWallSize &&
                  planeAnchor.planeExtent.height >= minWallSize else { continue }
            
            // Skip planes that are too far away
            let planePosition = planeAnchor.transform.columns.3
            let cameraPosition = frame.camera.transform.columns.3
            let distance = simd_distance(
                SIMD3<Float>(planePosition.x, planePosition.y, planePosition.z),
                SIMD3<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z)
            )
            
            guard distance <= maxWallDistance else { continue }
            
            // Mark this anchor as valid
            validAnchorIDs.insert(planeAnchor.identifier)
            
            // Check if we already have this wall
            if let wallID = anchorIDToWallID[planeAnchor.identifier], let existingWall = wallsById[wallID] {
                // Create updated wall with new anchor but same ID and properties
                let updatedWall = existingWall.updated(with: planeAnchor)
                wallsById[wallID] = updatedWall
                
                // Update visual entity if it exists
                if let entity = wallVisualEntities[wallID] {
                    updateWallVisualEntity(entity, forWall: existingWall, isSelected: existingWall.isSelected)
                }
                
                // Notify that the wall was updated
                DispatchQueue.main.async { [weak self] in
                    self?.onWallUpdated?(existingWall)
                }
            } else {
                // Create a new wall
                let newWall = WallPlane(anchor: planeAnchor)
                wallsById[newWall.id] = newWall
                anchorIDToWallID[planeAnchor.identifier] = newWall.id
                
                // Notify that a new wall was detected
                DispatchQueue.main.async { [weak self] in
                    self?.onWallDetected?(newWall)
                }
                
                LogManager.shared.info(message: "New wall detected. ID: \(newWall.id.uuidString)", category: "WallDetection")
            }
        }
        
        // Remove walls whose anchors are no longer valid
        let existingAnchorIDs = Set(anchorIDToWallID.keys)
        let removedAnchorIDs = existingAnchorIDs.subtracting(validAnchorIDs)
        
        for anchorID in removedAnchorIDs {
            if let wallID = anchorIDToWallID[anchorID] {
                // Remove wall references
                anchorIDToWallID.removeValue(forKey: anchorID)
                wallsById.removeValue(forKey: wallID)
                wallVisualEntities.removeValue(forKey: wallID)
                
                // If this was the selected wall, clear the selection
                if wallID == selectedWallID {
                    selectedWallID = nil
                }
                
                // Notify that the wall was removed
                DispatchQueue.main.async { [weak self] in
                    self?.onWallRemoved?(wallID)
                }
                
                LogManager.shared.info(message: "Wall removed. ID: \(wallID.uuidString)", category: "WallDetection")
            }
        }
    }
    
    // This function is no longer needed as we're using the updated(with:) method on WallPlane
    
    /// Create a visual entity for a wall
    /// - Parameter wall: The wall to create an entity for
    /// - Returns: A ModelEntity representing the wall
    private func createWallEntity(for wall: WallPlane) -> ModelEntity {
        // Ensure we're on the main thread for RealityKit operations
        if !Thread.isMainThread {
            var result: ModelEntity?
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                result = self.createWallEntity(for: wall)
                semaphore.signal()
            }
            
            semaphore.wait()
            return result!
        }
        
        // Create a mesh for the wall plane
        let width = CGFloat(wall.width)
        let height = CGFloat(wall.height)
        
        // Create a plane mesh that matches the wall dimensions
        let mesh = MeshResource.generatePlane(width: Float(width), height: Float(height))
        
        // Create a material for the wall visualization
        let material = self.createWallMaterial(isSelected: wall.isSelected)
        
        // Create the entity
        let entity = ModelEntity(mesh: mesh, materials: [material])
        
        // Position the entity at the center of the detected wall
        entity.position = convert(vector: wall.center)
        
        // Rotate the entity to match the wall orientation
        entity.orientation = convert(rotation: getWallRotation(from: wall.anchor))
        
        LogManager.shared.info(message: "Created visual entity for wall: \(wall.id.uuidString)", category: "WallDetection")
        
        return entity
    }
    
    /// Update the visual appearance of a wall entity
    /// - Parameters:
    ///   - entity: The entity to update
    ///   - wall: The wall data
    ///   - isSelected: Whether the wall is selected
    private func updateWallVisualEntity(_ entity: ModelEntity, forWall wall: WallPlane, isSelected: Bool) {
        // Ensure we're on the main thread for RealityKit updates
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateWallVisualEntity(entity, forWall: wall, isSelected: isSelected)
            }
            return
        }
        
        // Update the mesh to match the current wall dimensions
        let width = CGFloat(wall.width)
        let height = CGFloat(wall.height)
        entity.model?.mesh = MeshResource.generatePlane(width: Float(width), height: Float(height))
        
        // Update position and orientation
        entity.position = convert(vector: wall.center)
        entity.orientation = convert(rotation: getWallRotation(from: wall.anchor))
        
        // Update material based on selection state
        if entity.model?.materials.count ?? 0 > 0 {
            entity.model?.materials[0] = createWallMaterial(isSelected: isSelected)
        } else {
            entity.model?.materials = [createWallMaterial(isSelected: isSelected)]
        }
    }
    
    /// Create a material for wall visualization
    /// - Parameter isSelected: Whether the wall is selected
    /// - Returns: A material for the wall
    private func createWallMaterial(isSelected: Bool) -> Material {
        // Create material based on selection state
        let color: UIColor = isSelected ?
            UIColor(Constants.AR.selectedWallIndicatorColor) :
            UIColor(Constants.AR.wallIndicatorColor)
        
        // Create a basic semi-transparent material
        let material = SimpleMaterial(
            color: color.withAlphaComponent(0.7),
            roughness: 0.5,
            isMetallic: false
        )
        
        return material
    }
    
    /// Get the rotation quaternion for a wall
    /// - Parameter anchor: The plane anchor
    /// - Returns: A rotation quaternion
    private func getWallRotation(from anchor: ARPlaneAnchor) -> simd_quatf {
        // Extract the orientation from the anchor transform
        let transform = anchor.transform
        
        // The normal vector of the plane is the third column of the rotation matrix
        let normal = simd_normalize(SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
        
        // Create a rotation that aligns the plane with this normal
        // For vertical planes, this will typically orient them perpendicular to the floor
        return simd_quaternion(0, normal.y, 0, normal.x)
    }
    
    /// Convert a SIMD3 vector to a SIMD3<Float>
    /// - Parameter vector: The vector to convert
    /// - Returns: A SIMD3<Float> vector
    private func convert(vector: SIMD3<Float>) -> SIMD3<Float> {
        return vector
    }
    
    /// Convert a quaternion to a proper RealityKit quaternion
    /// - Parameter rotation: The rotation quaternion
    /// - Returns: A simd_quatf rotation
    private func convert(rotation: simd_quatf) -> simd_quatf {
        return rotation
    }
}

// Note: The updated(with:) method is now directly in the WallPlane struct
// and not needed here as an extension
