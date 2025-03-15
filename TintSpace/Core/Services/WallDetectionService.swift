////
////  WallDetectionService.swift
////  TintSpace
////
//
//import Foundation
//import ARKit
//import RealityKit
//import Combine
//
///// Protocol defining the wall detection service capabilities
//protocol WallDetectionServiceProtocol {
//    /// Current detected walls
//    var detectedWalls: [WallPlane] { get }
//    
//    /// Wall detection events
//    var onWallDetected: ((WallPlane) -> Void)? { get set }
//    var onWallUpdated: ((WallPlane) -> Void)? { get set }
//    var onWallRemoved: ((UUID) -> Void)? { get set }
//    
//    /// Select a wall for painting
//    func selectWall(withID id: UUID)
//    func deselectWall()
//    var selectedWall: WallPlane? { get }
//    
//    /// Start/stop detection
//    func startWallDetection()
//    func stopWallDetection()
//    
//    /// Process ARKit frame updates
//    func processFrame(_ frame: ARFrame)
//    
//    /// Get visual entity for a wall
//    func getOrCreateVisualEntity(for wall: WallPlane) -> ModelEntity
//    
//    /// Clear all walls (e.g., when restarting session)
//    func clearWalls()
//    
//    func enableDebugVisualization()
//}
//
///// Service responsible for detecting, tracking and managing walls in AR space
//final class WallDetectionService: ObservableObject, WallDetectionServiceProtocol {
//    // MARK: - Private Properties
//    
//    /// ARSession manager to coordinate with
//    private weak var arSessionManager: ARSessionManager?
//    
//    /// Dictionary to store detected walls by their ID
//    @Published private var wallsById: [UUID: WallPlane] = [:]
//    
//    /// Dictionary to map ARPlaneAnchor identifiers to our wall IDs
//    private var anchorIDToWallID: [UUID: UUID] = [:]
//    
//    /// Dictionary to track visual entities for each wall
//    private var wallVisualEntities: [UUID: ModelEntity] = [:]
//    
//    /// Currently selected wall ID
//    @Published private var selectedWallID: UUID?
//    
//    /// Queue for wall processing operations (serial queue for synchronized operations)
//    private let wallProcessingQueue = DispatchQueue(label: "com.tintspace.wallProcessingQueue", qos: .userInitiated)
//    
//    /// Cancellable storage for subscriptions
//    private var cancellables = Set<AnyCancellable>()
//    
//    /// Confidence threshold for wall detection
//    private let confidenceThreshold: Float
//    
//    /// Maximum distance for wall detection (in meters)
//    private let maxWallDistance: Float
//    
//    /// Timer for throttling updates
//    private var updateThrottleTimer: Timer?
//    
//    /// Minimum size for walls to be considered valid (in meters)
//    private let minWallSize: Float
//    
//    /// Thread safety lock for accessing shared resources
//    private let lock = NSLock()
//    
//    /// A value type to hold extracted frame data to prevent ARFrame retention
//    private struct FrameData {
//        let camera: ARCamera
//        let cameraTransform: simd_float4x4
//        let anchors: [ARAnchor]
//    }
//    
//    // MARK: - Public Properties
//    
//    /// Current detected walls, computed to maintain consistent API
//    var detectedWalls: [WallPlane] {
//        lock.lock()
//        defer { lock.unlock() }
//        return Array(wallsById.values)
//    }
//    
//    /// Callbacks for wall detection events
//    var onWallDetected: ((WallPlane) -> Void)?
//    var onWallUpdated: ((WallPlane) -> Void)?
//    var onWallRemoved: ((UUID) -> Void)?
//    
//    /// Currently selected wall
//    var selectedWall: WallPlane? {
//        lock.lock()
//        defer { lock.unlock() }
//        guard let selectedWallID = selectedWallID else { return nil }
//        return wallsById[selectedWallID]
//    }
//    
//    // MARK: - Initialization
//    
//    /// Initialize the wall detection service
//    /// - Parameters:
//    ///   - arSessionManager: The AR session manager to coordinate with
//    ///   - confidenceThreshold: Threshold for wall detection confidence (0.0-1.0)
//    ///   - maxWallDistance: Maximum distance for wall detection in meters
//    ///   - minWallSize: Minimum size for walls in meters
//    init(
//        arSessionManager: ARSessionManager,
//        confidenceThreshold: Float = Constants.AR.wallDetectionConfidenceThreshold,
//        maxWallDistance: Float = Constants.AR.maxWallDistance,
//        minWallSize: Float = 0.5
//    ) {
//        self.arSessionManager = arSessionManager
//        self.confidenceThreshold = confidenceThreshold
//        self.maxWallDistance = maxWallDistance
//        self.minWallSize = minWallSize
//        
//        LogManager.shared.info(message: "WallDetectionService initialized", category: "WallDetection")
//        
//        // Configure ARSession manager to forward frame updates
//        configureARSessionManager()
//        setupObservers()
//    }
//    
//    // MARK: - Configuration
//    
//    private func configureARSessionManager() {
//        // Set up frame callback from the ARSessionManager
//        arSessionManager?.onFrameUpdated = { [weak self] frame in
//            guard let self = self else { return }
//            
//            // Extract only the data we need from the frame to avoid retaining it
//            let frameData = self.extractFrameData(from: frame)
//            
//            // Process the extracted data on a background queue
//            self.processFrame(withData: frameData)
//        }
//    }
//    
//    // Extract only the data we need from ARFrame to avoid retention
//    private func extractFrameData(from frame: ARFrame) -> FrameData {
//        return FrameData(
//            camera: frame.camera,
//            cameraTransform: frame.camera.transform,
//            anchors: frame.anchors
//        )
//    }
//    
//    // MARK: - Public Methods
//    
//    /// Start wall detection process
//    func startWallDetection() {
//        LogManager.shared.info(message: "Starting wall detection", category: "WallDetection")
//        
//        // Nothing to do explicitly here as the processing happens
//        // when ARSessionManager provides frames
//    }
//    
//    /// Stop wall detection process
//    func stopWallDetection() {
//        LogManager.shared.info(message: "Stopping wall detection", category: "WallDetection")
//        
//        // Cancel any pending updates
//        updateThrottleTimer?.invalidate()
//        updateThrottleTimer = nil
//    }
//    
//    /// Select a wall for painting
//    /// - Parameter id: The ID of the wall to select
//    func selectWall(withID id: UUID) {
//        wallProcessingQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            self.lock.lock()
//            
//            // Deselect the currently selected wall if any
//            if let currentSelectedID = self.selectedWallID, var currentWall = self.wallsById[currentSelectedID] {
//                currentWall.isSelected = false
//                self.wallsById[currentSelectedID] = currentWall
//                
//                // Store the wall to update outside the lock
//                let wallToUpdate = currentWall
//                let entityToUpdate = self.wallVisualEntities[currentSelectedID]
//                
//                self.lock.unlock()
//                
//                // Update visual entity for previously selected wall
//                if let entity = entityToUpdate {
//                    self.updateWallVisualEntity(entity, forWall: wallToUpdate, isSelected: false)
//                }
//                
//                // Notify that the wall was updated (deselected)
//                DispatchQueue.main.async {
//                    self.onWallUpdated?(wallToUpdate)
//                }
//            } else {
//                self.lock.unlock()
//            }
//            
//            self.lock.lock()
//            
//            // Select the new wall if it exists
//            if var targetWall = self.wallsById[id] {
//                targetWall.isSelected = true
//                self.wallsById[id] = targetWall
//                self.selectedWallID = id
//                
//                // Store variables to use outside the lock
//                let wallToUpdate = targetWall
//                let entityToUpdate = self.wallVisualEntities[id]
//                
//                self.lock.unlock()
//                
//                // Update visual entity for newly selected wall
//                if let entity = entityToUpdate {
//                    self.updateWallVisualEntity(entity, forWall: wallToUpdate, isSelected: true)
//                }
//                
//                // Notify that the wall was updated (selected)
//                DispatchQueue.main.async {
//                    self.onWallUpdated?(wallToUpdate)
//                }
//                
//                LogManager.shared.info(message: "Wall selected: \(id.uuidString)", category: "WallDetection")
//            } else {
//                self.lock.unlock()
//                LogManager.shared.warning("Attempted to select nonexistent wall: \(id.uuidString)", category: "WallDetection")
//            }
//        }
//    }
//    
//    /// Deselect the currently selected wall
//    func deselectWall() {
//        self.lock.lock()
//        guard let selectedWallID = self.selectedWallID else {
//            self.lock.unlock()
//            return
//        }
//        
//        // Store the ID to use outside the lock
//        let wallID = selectedWallID
//        self.lock.unlock()
//        
//        wallProcessingQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            self.lock.lock()
//            guard var wall = self.wallsById[wallID] else {
//                self.lock.unlock()
//                return
//            }
//            
//            wall.isSelected = false
//            self.wallsById[wallID] = wall
//            self.selectedWallID = nil
//            
//            // Store data to use outside the lock
//            let wallToUpdate = wall
//            let entityToUpdate = self.wallVisualEntities[wallID]
//            
//            self.lock.unlock()
//            
//            // Update visual entity
//            if let entity = entityToUpdate {
//                self.updateWallVisualEntity(entity, forWall: wallToUpdate, isSelected: false)
//            }
//            
//            // Notify that the wall was updated (deselected)
//            DispatchQueue.main.async {
//                self.onWallUpdated?(wallToUpdate)
//            }
//            
//            LogManager.shared.info(message: "Wall deselected: \(wallID.uuidString)", category: "WallDetection")
//        }
//    }
//    
//    /// Process ARKit frame to detect and update walls
//    /// - Parameter frame: The ARFrame to process
//    func processFrame(_ frame: ARFrame) {
//        // Extract only the data we need from the frame to avoid retention
//        let frameData = extractFrameData(from: frame)
//        
//        // Process the extracted data
//        processFrame(withData: frameData)
//    }
//    
//    /// Internal method to process extracted frame data
//    /// - Parameter frameData: The extracted data from an ARFrame
//    private func processFrame(withData frameData: FrameData) {
//        // Skip processing if session is not running
//        guard arSessionManager?.isSessionRunning == true else { return }
//        
//        // Throttle updates to avoid too frequent processing
//        // Process on main thread but perform actual work on background
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self, self.updateThrottleTimer == nil else { return }
//            
//            self.updateThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
//                self?.updateThrottleTimer = nil
//                
//                // Process data on background queue
//                self?.wallProcessingQueue.async {
//                    self?.processPlaneAnchors(anchors: frameData.anchors, cameraTransform: frameData.cameraTransform)
//                }
//            }
//        }
//    }
//    
//    /// Get or create a visual entity for a wall
//    /// - Parameter wall: The wall to create or get a visual entity for
//    /// - Returns: A ModelEntity representing the wall
//    func getOrCreateVisualEntity(for wall: WallPlane) -> ModelEntity {
//        // Ensure we're on the main thread for RealityKit operations
//        if !Thread.isMainThread {
//            var result: ModelEntity?
//            let semaphore = DispatchSemaphore(value: 0)
//            
//            DispatchQueue.main.async {
//                result = self.getOrCreateVisualEntity(for: wall)
//                semaphore.signal()
//            }
//            
//            semaphore.wait()
//            return result!
//        }
//        
//        self.lock.lock()
//        if let existingEntity = wallVisualEntities[wall.id] {
//            self.lock.unlock()
//            return existingEntity
//        }
//        self.lock.unlock()
//        
//        // Create a new entity
//        let entity = createWallEntity(for: wall)
//        
//        self.lock.lock()
//        wallVisualEntities[wall.id] = entity
//        self.lock.unlock()
//        
//        // Update selection state
//        updateWallVisualEntity(entity, forWall: wall, isSelected: wall.isSelected)
//        
//        return entity
//    }
//    
//    /// Clear all wall data (e.g., when resetting AR session)
//    func clearWalls() {
//        wallProcessingQueue.async { [weak self] in
//            guard let self = self else { return }
//            
//            self.lock.lock()
//            
//            // Copy wall IDs to avoid modification during iteration
//            let wallIDs = Set(self.wallsById.keys)
//            
//            // Clear all wall data
//            self.wallsById.removeAll()
//            self.anchorIDToWallID.removeAll()
//            self.wallVisualEntities.removeAll()
//            self.selectedWallID = nil
//            
//            self.lock.unlock()
//            
//            // Notify about removed walls
//            DispatchQueue.main.async {
//                for wallID in wallIDs {
//                    self.onWallRemoved?(wallID)
//                }
//            }
//            
//            LogManager.shared.info(message: "All walls cleared", category: "WallDetection")
//        }
//    }
//    
//    // MARK: - Private Methods
//    
//    /// Set up observers for AR session events
//    private func setupObservers() {
//        guard arSessionManager != nil else {
//            LogManager.shared.error("Cannot setup observers: ARSessionManager is nil", category: "WallDetection")
//            return
//        }
//        
//        // Observe session interruptions to handle wall tracking resumption
//        NotificationCenter.default
//            .publisher(for: .customARSessionWasInterrupted)
//            .sink { [weak self] _ in
//                LogManager.shared.warning("AR session interrupted, wall detection paused", category: "WallDetection")
//                self?.stopWallDetection()
//            }
//            .store(in: &cancellables)
//        
//        NotificationCenter.default
//            .publisher(for: .customARSessionInterruptionEnded)
//            .sink { [weak self] _ in
//                LogManager.shared.info(message: "AR session interruption ended, resuming wall detection", category: "WallDetection")
//                self?.startWallDetection()
//            }
//            .store(in: &cancellables)
//    }
//    
//    /// Process plane anchors extracted from an AR frame
//    /// - Parameters:
//    ///   - anchors: The anchors to process
//    ///   - cameraTransform: The current camera transform
//    private func processPlaneAnchors(anchors: [ARAnchor], cameraTransform: simd_float4x4) {
//        // Track valid plane anchors and existing walls to detect removals
//        var validAnchorIDs = Set<UUID>()
//        var updatedWalls: [WallPlane] = []
//        var newWalls: [WallPlane] = []
//        var removedWallIDs: [UUID] = []
//        
//        for anchor in anchors {
//            guard let planeAnchor = anchor as? ARPlaneAnchor else { continue }
//            
//            // Only consider vertical planes (walls)
//            guard planeAnchor.alignment == .vertical else { continue }
//            
//            // Skip planes that are too small
//            guard planeAnchor.planeExtent.width >= minWallSize &&
//                  planeAnchor.planeExtent.height >= minWallSize else { continue }
//            
//            // Skip planes that are too far away
//            let planePosition = planeAnchor.transform.columns.3
//            let cameraPosition = cameraTransform.columns.3
//            let distance = simd_distance(
//                SIMD3<Float>(planePosition.x, planePosition.y, planePosition.z),
//                SIMD3<Float>(cameraPosition.x, cameraPosition.y, cameraPosition.z)
//            )
//            
//            guard distance <= maxWallDistance else { continue }
//            
//            // Mark this anchor as valid
//            validAnchorIDs.insert(planeAnchor.identifier)
//            
//            self.lock.lock()
//            
//            // Check if we already have this wall
//            if let wallID = anchorIDToWallID[planeAnchor.identifier], let existingWall = wallsById[wallID] {
//                // Create updated wall with new anchor but same ID and properties
//                let updatedWall = existingWall.updated(with: planeAnchor)
//                wallsById[wallID] = updatedWall
//                updatedWalls.append(updatedWall)
//                
//                self.lock.unlock()
//            } else {
//                // Create a new wall
//                let newWall = WallPlane(anchor: planeAnchor)
//                wallsById[newWall.id] = newWall
//                anchorIDToWallID[planeAnchor.identifier] = newWall.id
//                newWalls.append(newWall)
//                
//                self.lock.unlock()
//                
//                LogManager.shared.info(message: "New wall detected. ID: \(newWall.id.uuidString)", category: "WallDetection")
//            }
//        }
//        
//        self.lock.lock()
//        
//        // Remove walls whose anchors are no longer valid
//        let existingAnchorIDs = Set(anchorIDToWallID.keys)
//        let removedAnchorIDs = existingAnchorIDs.subtracting(validAnchorIDs)
//        
//        for anchorID in removedAnchorIDs {
//            if let wallID = anchorIDToWallID[anchorID] {
//                // Remove wall references
//                anchorIDToWallID.removeValue(forKey: anchorID)
//                wallsById.removeValue(forKey: wallID)
//                wallVisualEntities.removeValue(forKey: wallID)
//                removedWallIDs.append(wallID)
//                
//                // If this was the selected wall, clear the selection
//                if wallID == selectedWallID {
//                    selectedWallID = nil
//                }
//            }
//        }
//        
//        self.lock.unlock()
//        
//        // Process all notifications on the main thread
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            // Notify about new walls
//            for wall in newWalls {
//                self.onWallDetected?(wall)
//            }
//            
//            // Notify about updated walls
//            for wall in updatedWalls {
//                self.onWallUpdated?(wall)
//                
//                // Update visual entity if it exists
//                self.lock.lock()
//                if let entity = self.wallVisualEntities[wall.id] {
//                    let isSelected = wall.isSelected
//                    self.lock.unlock()
//                    self.updateWallVisualEntity(entity, forWall: wall, isSelected: isSelected)
//                } else {
//                    self.lock.unlock()
//                }
//            }
//            
//            // Notify about removed walls
//            for wallID in removedWallIDs {
//                self.onWallRemoved?(wallID)
//                LogManager.shared.info(message: "Wall removed. ID: \(wallID.uuidString)", category: "WallDetection")
//            }
//        }
//    }
//    
//    /// Create a visual entity for a wall with enhanced visibility
//    /// - Parameter wall: The wall to create an entity for
//    /// - Returns: A ModelEntity representing the wall
//    private func createWallEntity(for wall: WallPlane) -> ModelEntity {
//        // Ensure we're on the main thread for RealityKit operations
//        if !Thread.isMainThread {
//            var result: ModelEntity?
//            let semaphore = DispatchSemaphore(value: 0)
//            
//            DispatchQueue.main.async {
//                result = self.createWallEntity(for: wall)
//                semaphore.signal()
//            }
//            
//            semaphore.wait()
//            return result!
//        }
//        
//        // Create a mesh for the wall plane
//        let width = CGFloat(wall.width)
//        let height = CGFloat(wall.height)
//        
//        // Create a plane mesh that matches the wall dimensions
//        let mesh = MeshResource.generatePlane(width: Float(width), height: Float(height))
//        
//        // Create a material for the wall visualization
//        let material = self.createWallMaterial(isSelected: wall.isSelected)
//        
//        // Create the entity
//        let entity = ModelEntity(mesh: mesh, materials: [material])
//        
//        // Scale slightly larger to be more visible (1% larger)
//        entity.scale = SIMD3<Float>(1.01, 1.01, 1.01)
//        
//        // Position the entity at the center of the detected wall
//        entity.position = convert(vector: wall.center)
//        
//        // Rotate the entity to match the wall orientation
//        entity.orientation = convert(rotation: getWallRotation(from: wall.anchor))
//        
//        // Make sure the entity is set to be visible
//        entity.isEnabled = true
//        
//        // Move slightly in front of the actual wall for better visibility
//        let wallNormal = SIMD3<Float>(
//            wall.anchor.transform.columns.2.x,
//            wall.anchor.transform.columns.2.y,
//            wall.anchor.transform.columns.2.z
//        )
//        let normalizedNormal = simd_normalize(wallNormal)
//        
//        // Move 1cm in front of the wall along its normal vector
//        entity.position += normalizedNormal * 0.01
//        
//        LogManager.shared.info(message: "Created enhanced visual entity for wall: \(wall.id.uuidString)", category: "WallDetection")
//        
//        return entity
//    }
//
//    /// Update the visual appearance of a wall entity with enhanced visibility
//    /// - Parameters:
//    ///   - entity: The entity to update
//    ///   - wall: The wall data
//    ///   - isSelected: Whether the wall is selected
//    private func updateWallVisualEntity(_ entity: ModelEntity, forWall wall: WallPlane, isSelected: Bool) {
//        // Ensure we're on the main thread for RealityKit updates
//        if !Thread.isMainThread {
//            DispatchQueue.main.async {
//                self.updateWallVisualEntity(entity, forWall: wall, isSelected: isSelected)
//            }
//            return
//        }
//        
//        // Update the mesh to match the current wall dimensions
//        let width = CGFloat(wall.width)
//        let height = CGFloat(wall.height)
//        entity.model?.mesh = MeshResource.generatePlane(width: Float(width), height: Float(height))
//        
//        // Update position and orientation
//        entity.position = convert(vector: wall.center)
//        entity.orientation = convert(rotation: getWallRotation(from: wall.anchor))
//        
//        // Move slightly in front of the actual wall for better visibility
//        let wallNormal = SIMD3<Float>(
//            wall.anchor.transform.columns.2.x,
//            wall.anchor.transform.columns.2.y,
//            wall.anchor.transform.columns.2.z
//        )
//        let normalizedNormal = simd_normalize(wallNormal)
//        entity.position += normalizedNormal * 0.01
//        
//        // Update material based on selection state
//        if entity.model?.materials.count ?? 0 > 0 {
//            entity.model?.materials[0] = createWallMaterial(isSelected: isSelected)
//        } else {
//            entity.model?.materials = [createWallMaterial(isSelected: isSelected)]
//        }
//        
//        // Make sure the entity is visible
//        entity.isEnabled = true
//    }
//    
//    /// Create a material for wall visualization
//    /// - Parameter isSelected: Whether the wall is selected
//    /// - Returns: A material for the wall
//    private func createWallMaterial(isSelected: Bool) -> Material {
//        // Create material based on selection state with higher opacity and contrast
//        let color: UIColor = isSelected ?
//            UIColor(Constants.AR.selectedWallIndicatorColor) :
//            UIColor(Constants.AR.wallIndicatorColor)
//        
//        // Increase opacity from 0.7 to 0.9 to make walls more visible
//        let baseColor = color.withAlphaComponent(0.9)
//        
//        // Create a simple material that's more visible during testing
//        var material = SimpleMaterial()
//        
//        // Set base color with higher opacity
//        material.baseColor = MaterialColorParameter.color(baseColor)
//        
//        // Use lower roughness for more visibility
//        material.roughness = MaterialScalarParameter(floatLiteral: 0.3)
//        
//        // Set metallic to 0 to avoid lighting issues
//        material.metallic = MaterialScalarParameter(floatLiteral: 0.0)
//        
//        return material
//    }
//    
//    /// Get the rotation quaternion for a wall
//    /// - Parameter anchor: The plane anchor
//    /// - Returns: A rotation quaternion
//    private func getWallRotation(from anchor: ARPlaneAnchor) -> simd_quatf {
//        // Extract the orientation from the anchor transform
//        let transform = anchor.transform
//        
//        // The normal vector of the plane is the third column of the rotation matrix
//        let normal = simd_normalize(SIMD3<Float>(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
//        
//        // Create a rotation that aligns the plane with this normal
//        // For vertical planes, this will typically orient them perpendicular to the floor
//        return simd_quaternion(0, normal.y, 0, normal.x)
//    }
//    
//    /// Convert a SIMD3 vector to a SIMD3<Float>
//    /// - Parameter vector: The vector to convert
//    /// - Returns: A SIMD3<Float> vector
//    private func convert(vector: SIMD3<Float>) -> SIMD3<Float> {
//        return vector
//    }
//    
//    /// Convert a quaternion to a proper RealityKit quaternion
//    /// - Parameter rotation: The rotation quaternion
//    /// - Returns: A simd_quatf rotation
//    private func convert(rotation: simd_quatf) -> simd_quatf {
//        return rotation
//    }
//}
//
//
//extension WallDetectionService {
//    /// Creates a debug entity to help visualize walls during development
//    /// Call this method in addition to normal entity creation during testing
//    func createDebugEntityForWall(_ wall: WallPlane) -> ModelEntity {
//        // Create wireframe box to make wall boundaries clear
//        let boxSize = SIMD3<Float>(wall.width, wall.height, 0.01)
//        let boxMesh = MeshResource.generateBox(size: boxSize)
//        
//        // Create bright wireframe material that's easy to see
//        var material = UnlitMaterial(color: .red)
//        material.color = .init(tint: .red.withAlphaComponent(0.8))
//        
//        // Create the debug entity
//        let debugEntity = ModelEntity(mesh: boxMesh, materials: [material])
//        
//        // Position at wall center
//        debugEntity.position = convert(vector: wall.center)
//        
//        // Use same orientation as the wall
//        debugEntity.orientation = convert(rotation: getWallRotation(from: wall.anchor))
//        
//        // Set to wireframe mode for debugging
//        if #available(iOS 15.0, *) {
//            // On iOS 15+, set to wireframe if available
//            debugEntity.model?.materials = [material]
//        }
//        
//        return debugEntity
//    }
//    
//    /// Add this to your viewDidLoad or setupARView method to enable debug visualization
//    func enableDebugVisualization() {
//        // Replace your existing onWallDetected with this during debugging
//        let originalWallDetectedHandler = self.onWallDetected
//        
//        self.onWallDetected = { [weak self] wall in
//            // Call the original handler first
//            originalWallDetectedHandler?(wall)
//            
//            // Then add debug visualization
//            guard let self = self, let arView = self.arSessionManager?.arView else { return }
//            
//            DispatchQueue.main.async {
//                // Create debug entity
//                let debugEntity = self.createDebugEntityForWall(wall)
//                
//                // Add to scene
//                let anchor = AnchorEntity(world: .zero)
//                arView.scene.addAnchor(anchor)
//                anchor.addChild(debugEntity)
//                
//                LogManager.shared.info(message: "Added debug entity for wall: \(wall.id.uuidString)", category: "Debug")
//            }
//        }
//    }
//}
