//
//  WallEntity.swift
//  TintSpace
//
//  Created for TintSpace on 3/16/25.
//

import Foundation
import ARKit
import RealityKit

/// Represents a detected wall in the AR scene
class WallEntity: Identifiable {
    // MARK: - Properties
    
    /// Unique identifier for the wall, derived from the anchor's identifier
    let id: UUID
    
    /// Reference to the ARKit anchor for this wall
    private(set) var anchor: ARPlaneAnchor
    
    /// RealityKit entity representing this wall visually (optional, will be set when visualization is needed)
    var visualEntity: ModelEntity?
    
    /// Whether this wall is currently selected by the user
    private(set) var isSelected: Bool = false
    
    /// Time when this wall was first detected
    private let detectionTime: Date = Date()
    
    /// Time of the last update to this wall
    private(set) var lastUpdateTime: Date = Date()
    
    // MARK: - Computed Properties
    
    /// Wall dimensions based on the anchor's extent
    var dimensions: SIMD2<Float> {
        if #available(iOS 16.0, *) {
            return SIMD2<Float>(anchor.planeExtent.width, anchor.planeExtent.height)
        } else {
            return SIMD2<Float>(anchor.extent.x, anchor.extent.z)
        }
    }
    
    /// Wall center position in world space
    var center: SIMD3<Float> {
        return anchor.transform.columns.3.xyz
    }
    
    // MARK: - Initialization
    
    /// Initialize a wall entity with an AR plane anchor
    /// - Parameter anchor: The ARKit plane anchor representing this wall
    init(anchor: ARPlaneAnchor) {
        self.id = anchor.identifier
        self.anchor = anchor
        
        LogManager.shared.info(message: "Created new wall entity with ID: \(id)", category: "WallEntity")
    }
    
    // MARK: - Public Methods
    
    /// Update the wall with a new anchor
    /// - Parameter newAnchor: The updated plane anchor
    func update(with newAnchor: ARPlaneAnchor) {
        self.anchor = newAnchor
        self.lastUpdateTime = Date()
        
        LogManager.shared.info(message: "Updated wall entity \(id)", category: "WallEntity")
    }
    
    /// Set the selection state of this wall
    /// - Parameter selected: Whether the wall is selected
    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        
        isSelected = selected
        
        // In the future, we'll update visualization here
        
        LogManager.shared.info(message: "Wall \(id) selection state changed to \(selected)", category: "WallEntity")
    }
    
    /// Basic method to set up visualization for testing purposes
    /// - Parameter scene: The RealityKit scene to add the entity to
    func setupVisualization(in scene: RealityKit.Scene? = nil) {
        // Create a simple mesh for the wall based on dimensions
        let width = CGFloat(dimensions.x)
        let height = CGFloat(dimensions.y)
        let wallMesh = MeshResource.generatePlane(width: Float(width), height: Float(height))
        // Create entity with a basic material for visibility
        let wallEntity = ModelEntity(mesh: wallMesh)
        let material = SimpleMaterial(color: .blue.withAlphaComponent(0.3), isMetallic: false)
        wallEntity.model?.materials = [material]
        
        // Set the transform to match the anchor
        wallEntity.transform = Transform(matrix: anchor.transform)
        
        // Store the entity
        self.visualEntity = wallEntity
        
        // Add to scene if provided
        if let scene = scene {
            let anchorEntity = AnchorEntity(world: .zero)
            anchorEntity.addChild(wallEntity)
            scene.addAnchor(anchorEntity)
        }
        
        LogManager.shared.info(message: "Set up basic visualization for wall \(id)", category: "WallEntity")
    }
}

// MARK: - Helper Extensions

extension SIMD4 {
    /// Extract the XYZ components of a SIMD4
    var xyz: SIMD3<Scalar> {
        return SIMD3(x: self.x, y: self.y, z: self.z)
    }
}
