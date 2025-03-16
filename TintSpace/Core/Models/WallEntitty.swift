//
//  WallEntity.swift
//  TintSpace
//
//  Created for TintSpace on 3/16/25.
//

import Foundation
import ARKit
import RealityKit
import UIKit

/// Represents a detected wall in the AR scene
class WallEntity: Identifiable {
    // MARK: - Properties
    
    /// Unique identifier for the wall, derived from the anchor's identifier
    let id: UUID
    
    /// Reference to the ARKit anchor for this wall
    private(set) var anchor: ARPlaneAnchor
    
    /// RealityKit entity representing this wall visually
    var visualEntity: ModelEntity?
    
    /// Anchor entity that holds the visual entity in the scene
    var anchorEntity: AnchorEntity?
    
    /// Whether this wall is currently selected by the user
    private(set) var isSelected: Bool = false
    
    /// Current color applied to the wall (if any)
    private(set) var currentColor: UIColor?
    
    /// History of colors applied to this wall for undo/redo
    private var colorHistory: [UIColor] = []
    
    /// Current position in the color history for undo/redo
    private var historyPosition: Int = -1
    
    /// Maximum number of color changes to store in history
    private let maxHistorySize = 20
    
    /// Time when this wall was first detected
    private let detectionTime: Date = Date()
    
    /// Time of the last update to this wall
    private(set) var lastUpdateTime: Date = Date()
    
    /// Current paint finish mode
    private(set) var paintFinish: PaintFinish = .matte
    
    // MARK: - Paint Finish Types
    
    /// Paint finish styles
    enum PaintFinish {
        case matte
        case satin
        case gloss
        
        /// Get material properties for this finish
        var materialProperties: (roughness: Float, metallic: Float, specular: Float) {
            switch self {
            case .matte:
                return (roughness: 0.9, metallic: 0.0, specular: 0.1)
            case .satin:
                return (roughness: 0.5, metallic: 0.0, specular: 0.3)
            case .gloss:
                return (roughness: 0.1, metallic: 0.0, specular: 0.7)
            }
        }
    }
    
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
    
    /// Normal vector of the wall (perpendicular to surface)
    var normal: SIMD3<Float> {
        // For vertical planes, the normal is along the X or Z axis
        let normalVector = anchor.transform.columns.2.xyz
        return normalVector
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
        
//        LogManager.shared.info(message: "Updated wall entity \(id)", category: "WallEntity")
    }
    
    /// Set the selection state of this wall
    /// - Parameter selected: Whether the wall is selected
    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        
        isSelected = selected
        
        LogManager.shared.info(message: "Wall \(id) selection state changed to \(selected)", category: "WallEntity")
    }
    
    /// Apply a color to the wall
    /// - Parameter color: The color to apply
    func applyColor(_ color: UIColor) {
        // Save to history for undo/redo
        if currentColor != color {
            // If we're not at the end of the history, remove all entries after current position
            if historyPosition < colorHistory.count - 1 {
                colorHistory = Array(colorHistory[0...historyPosition])
            }
            
            // Add to history
            colorHistory.append(color)
            
            // Trim history if too large
            if colorHistory.count > maxHistorySize {
                colorHistory.removeFirst(colorHistory.count - maxHistorySize)
            }
            
            // Update position
            historyPosition = colorHistory.count - 1
            
            // Store current color
            currentColor = color
            
            LogManager.shared.info(message: "Applied color to wall \(id)", category: "WallEntity")
        }
    }
    
    /// Undo the last color change
    /// - Returns: True if undo was successful, false if no more history
    @discardableResult
    func undoColorChange() -> Bool {
        guard historyPosition > 0 else {
            LogManager.shared.info(message: "No color changes to undo for wall \(id)", category: "WallEntity")
            return false
        }
        
        // Move back in history
        historyPosition -= 1
        
        // Get previous color
        currentColor = colorHistory[historyPosition]
        
        LogManager.shared.info(message: "Undid color change for wall \(id)", category: "WallEntity")
        return true
    }
    
    /// Redo the last undone color change
    /// - Returns: True if redo was successful, false if no more changes to redo
    @discardableResult
    func redoColorChange() -> Bool {
        guard historyPosition < colorHistory.count - 1 else {
            LogManager.shared.info(message: "No color changes to redo for wall \(id)", category: "WallEntity")
            return false
        }
        
        // Move forward in history
        historyPosition += 1
        
        // Get next color
        currentColor = colorHistory[historyPosition]
        
        LogManager.shared.info(message: "Redid color change for wall \(id)", category: "WallEntity")
        return true
    }
    
    /// Set the paint finish for this wall
    /// - Parameter finish: The paint finish to apply
    func setPaintFinish(_ finish: PaintFinish) {
        self.paintFinish = finish
        LogManager.shared.info(message: "Set paint finish to \(finish) for wall \(id)", category: "WallEntity")
    }
    
    // MARK: - Visualization Methods

    /// Set up visualization for the detected wall
    /// - Parameter scene: The RealityKit scene to add the entity to
    func setupVisualization(in scene: RealityKit.Scene? = nil) {
        // Extract width from the anchor
        let width = anchor.extent.x
        let realHeight = 2.4 // Standard wall height
        
        LogManager.shared.info(message: "Wall \(id) detected with width: \(width), height: \(realHeight)", category: "WallEntity")
        
        // Create wall mesh with proper dimensions
        let wallMesh = MeshResource.generatePlane(width: width, height: Float(realHeight))
        
        // Create material (bright yellow for visibility)
        let material = SimpleMaterial(color: .yellow, isMetallic: false)
        let wallEntity = ModelEntity(mesh: wallMesh, materials: [material])
        
        // Create an anchor entity at the exact position of the plane anchor
        let anchorEntity = AnchorEntity(anchor: anchor)

        // Apply a simple rotation to make the plane vertical
        // The plane is created on the XZ plane, so rotate 90 degrees around X to make it vertical
        wallEntity.transform = Transform(
            scale: [1, 1, 1],
            rotation: simd_quatf(angle: -.pi/2, axis: [1, 0, 0]),
            translation: [0, Float(realHeight/2), 0] // Convert to Float explicitly
        )
        
        // Add wall entity to anchor entity
        anchorEntity.addChild(wallEntity)
        
        // Store references
        self.visualEntity = wallEntity
        self.anchorEntity = anchorEntity
        
        // Add to scene if provided
        if let scene = scene {
            scene.addAnchor(anchorEntity)
        }
        
        LogManager.shared.info(message: "Set up solid visualization for wall \(id)", category: "WallEntity")
    }
    
    /// Update the visualization based on current state
    func updateVisualization() {
        guard let visualEntity = visualEntity else {
            LogManager.shared.warning("Attempted to update visualization for wall \(id) but no visual entity exists", category: "WallEntity")
            return
        }
        
        // Only update materials based on state
        if isSelected {
            visualEntity.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
        } else if let color = currentColor {
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color.withAlphaComponent(0.95))
            let finishProps = paintFinish.materialProperties
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: finishProps.roughness)
            material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: finishProps.metallic)
            visualEntity.model?.materials = [material]
        } else {
            visualEntity.model?.materials = [SimpleMaterial(color: .yellow, isMetallic: false)]
        }
        
        // Important: Don't update the transform
    }

    /// Create a material based on the current state of the wall
    private func createWallMaterial() -> Material {
        // Return a solid color (Red) for testing purposes
        return SimpleMaterial(color: .red, isMetallic: false)
    }
}

// MARK: - Helper Extensions

extension SIMD4 {
    /// Extract the XYZ components of a SIMD4
    var xyz: SIMD3<Scalar> {
        return SIMD3(x: self.x, y: self.y, z: self.z)
    }
}
