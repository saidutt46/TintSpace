//
//  WallEntityManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/16/25.
//

import Foundation
import ARKit
import RealityKit
import Combine

/// Service responsible for managing wall entities in the AR scene
class WallEntityManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Collection of wall entities indexed by their identifier
    @Published private(set) var walls: [UUID: WallEntity] = [:]
    
    /// Currently selected wall entity
    @Published private(set) var selectedWall: WallEntity?
    
    /// Publisher for wall detection events
    let wallDetectedPublisher = PassthroughSubject<WallEntity, Never>()
    
    /// Publisher for wall selection events
    let wallSelectedPublisher = PassthroughSubject<WallEntity?, Never>()
    
    /// Publisher for wall update events
    let wallUpdatedPublisher = PassthroughSubject<WallEntity, Never>()
    
    /// Publisher for wall removal events
    let wallRemovedPublisher = PassthroughSubject<UUID, Never>()
    
    // MARK: - Private Properties
    
    /// Reference to the AR scene for entity visualization
    private weak var arScene: RealityKit.Scene?
    
    // MARK: - Initialization
    
    /// Initialize the wall entity manager with an optional AR scene
    /// - Parameter arScene: The RealityKit scene for visualization
    init(arScene: RealityKit.Scene? = nil) {
        self.arScene = arScene
        LogManager.shared.info(message: "WallEntityManager initialized", category: "WallManager")
    }
    
    // MARK: - Wall Registration and Management
    
    /// Register a new wall entity
    /// - Parameter wall: The wall entity to register
    /// - Returns: True if the wall was registered, false if it already exists
    @discardableResult
    func registerWall(_ wall: WallEntity) -> Bool {
        // Check if wall already exists
        guard walls[wall.id] == nil else {
            LogManager.shared.warning("Attempted to register wall \(wall.id) that already exists", category: "WallManager")
            return false
        }
        
        // Add to dictionary
        walls[wall.id] = wall
        
        // Set up visualization if we have an AR scene
        if let arScene = arScene {
            wall.setupVisualization(in: arScene)
        }
        
        // Publish wall detection event
        wallDetectedPublisher.send(wall)
        
        LogManager.shared.info(message: "Wall \(wall.id) registered", category: "WallManager")
        return true
    }
    
    /// Create and register a new wall entity from an AR plane anchor
    /// - Parameter anchor: The AR plane anchor representing a wall
    /// - Returns: The created wall entity
    @discardableResult
    func createAndRegisterWall(from anchor: ARPlaneAnchor) -> WallEntity {
        // Create new wall entity
        let wall = WallEntity(anchor: anchor)
        
        // Register it
        registerWall(wall)
        
        return wall
    }
    
    /// Update an existing wall entity with a new anchor
    /// - Parameter anchor: The updated plane anchor
    /// - Returns: True if the wall was updated, false if it doesn't exist
    @discardableResult
    func updateWall(with anchor: ARPlaneAnchor) -> Bool {
        // Check if wall exists
        guard let wall = walls[anchor.identifier] else {
            LogManager.shared.warning("Attempted to update nonexistent wall \(anchor.identifier)", category: "WallManager")
            return false
        }
        
        // Update the wall with new anchor
        wall.update(with: anchor)
        
        // Update visualization if needed
        updateWallVisualization(wall)
        
        // Publish wall update event
        wallUpdatedPublisher.send(wall)
        
//        LogManager.shared.info(message: "Wall \(wall.id) updated", category: "WallManager")
        return true
    }
    
    /// Remove a wall entity
    /// - Parameter id: The identifier of the wall to remove
    /// - Returns: True if the wall was removed, false if it doesn't exist
    @discardableResult
    func removeWall(withID id: UUID) -> Bool {
        // Check if wall exists
        guard let wall = walls[id] else {
            LogManager.shared.warning("Attempted to remove nonexistent wall \(id)", category: "WallManager")
            return false
        }
        
        // Clear selection if this wall was selected
        if selectedWall?.id == id {
            clearSelection()
        }
        
        // Remove visualization entity if it exists
        if let entity = wall.visualEntity, let arScene = arScene {
            // Find and remove the entity from the scene
            if let anchorEntity = entity.anchor {
                arScene.removeAnchor(anchorEntity)
            }
        }
        
        // Remove from dictionary
        walls.removeValue(forKey: id)
        
        // Publish wall removal event
        wallRemovedPublisher.send(id)
        
        LogManager.shared.info(message: "Wall \(id) removed", category: "WallManager")
        return true
    }
    
    /// Get a wall entity by its identifier
    /// - Parameter id: The wall identifier
    /// - Returns: The wall entity if found, nil otherwise
    func getWall(withID id: UUID) -> WallEntity? {
        return walls[id]
    }
    
    // MARK: - Wall Selection
    
    /// Select a wall entity
    /// - Parameter wall: The wall entity to select
    func selectWall(_ wall: WallEntity) {
        // Deselect current wall if different
        if let currentSelection = selectedWall, currentSelection.id != wall.id {
            currentSelection.setSelected(false)
            updateWallVisualization(currentSelection)
        }
        
        // Update selection state
        wall.setSelected(true)
        selectedWall = wall
        
        // Update visualization
        updateWallVisualization(wall)
        
        // Publish selection event
        wallSelectedPublisher.send(wall)
        
        LogManager.shared.info(message: "Wall \(wall.id) selected", category: "WallManager")
    }
    
    /// Select a wall by its identifier
    /// - Parameter id: The identifier of the wall to select
    /// - Returns: True if the wall was selected, false if it doesn't exist
    @discardableResult
    func selectWall(withID id: UUID) -> Bool {
        guard let wall = walls[id] else {
            LogManager.shared.warning("Attempted to select nonexistent wall \(id)", category: "WallManager")
            return false
        }
        
        selectWall(wall)
        return true
    }
    
    /// Clear the current wall selection
    func clearSelection() {
        guard let wall = selectedWall else { return }
        
        // Update selection state
        wall.setSelected(false)
        selectedWall = nil
        
        // Update visualization
        updateWallVisualization(wall)
        
        // Publish selection cleared event
        wallSelectedPublisher.send(nil)
        
        LogManager.shared.info(message: "Wall selection cleared", category: "WallManager")
    }
    
    // MARK: - Wall Visualization
    
    /// Update the visualization of a wall entity
    /// - Parameter wall: The wall entity to update
    private func updateWallVisualization(_ wall: WallEntity) {
        guard let _ = arScene else { return }
        
        // Update the wall's visual entity based on its current state
        wall.updateVisualization()
    }
    
    /// Set the scene for visualization
    /// - Parameter scene: The RealityKit scene
    func setScene(_ scene: RealityKit.Scene) {
        self.arScene = scene
        
        // Update all existing walls with the new scene
        for wall in walls.values {
            wall.setupVisualization(in: scene)
        }
        
        LogManager.shared.info(message: "AR scene set for WallEntityManager", category: "WallManager")
    }
    
    /// Apply a color to the selected wall
    /// - Parameter color: The color to apply
    /// - Returns: True if color was applied, false if no wall is selected
    @discardableResult
    func applyColorToSelectedWall(_ color: UIColor) -> Bool {
        guard let wall = selectedWall else {
            LogManager.shared.warning("Attempted to apply color with no wall selected", category: "WallManager")
            return false
        }
        
        // Apply color to wall
        wall.applyColor(color)
        
        // Update visualization
        updateWallVisualization(wall)
        
        LogManager.shared.info(message: "Applied color to wall \(wall.id)", category: "WallManager")
        return true
    }
    
    /// Apply a color to a specific wall
    /// - Parameters:
    ///   - color: The color to apply
    ///   - wallID: The identifier of the wall
    /// - Returns: True if color was applied, false if wall doesn't exist
    @discardableResult
    func applyColor(_ color: UIColor, toWallWithID wallID: UUID) -> Bool {
        guard let wall = walls[wallID] else {
            LogManager.shared.warning("Attempted to apply color to nonexistent wall \(wallID)", category: "WallManager")
            return false
        }
        
        // Apply color to wall
        wall.applyColor(color)
        
        // Update visualization
        updateWallVisualization(wall)
        
        LogManager.shared.info(message: "Applied color to wall \(wallID)", category: "WallManager")
        return true
    }
}
