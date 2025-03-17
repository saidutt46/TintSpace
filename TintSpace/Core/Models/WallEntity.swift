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
    
    /// Border entity to outline the wall
    var borderEntity: ModelEntity?
    
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
    
    /// How close the wall visualization should be to actual surface (offset in meters)
    private let wallOffset: Float = 0.0001
    
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
        
        // Update visualization to match new anchor dimensions
        updateVisualizationGeometry()
    }
    
    /// Set the selection state of this wall
    /// - Parameter selected: Whether the wall is selected
    func setSelected(_ selected: Bool) {
        guard isSelected != selected else { return }
        
        isSelected = selected
        updateVisualization()
        
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
            
            // Update the visual appearance
            updateVisualization()
            
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
        
        // Update the visual appearance
        updateVisualization()
        
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
        
        // Update the visual appearance
        updateVisualization()
        
        LogManager.shared.info(message: "Redid color change for wall \(id)", category: "WallEntity")
        return true
    }
    
    /// Set the paint finish for this wall
    /// - Parameter finish: The paint finish to apply
    func setPaintFinish(_ finish: PaintFinish) {
        self.paintFinish = finish
        updateVisualization()
        LogManager.shared.info(message: "Set paint finish to \(finish) for wall \(id)", category: "WallEntity")
    }
    
    // MARK: - Classification Helper Methods
    
    /// Get a description of the plane anchor's classification
    private func getClassificationDescription(for anchor: ARPlaneAnchor) -> String {
        if #available(iOS 12.0, *), ARPlaneAnchor.isClassificationSupported {
            switch anchor.classification {
            case .wall:
                return "Wall"
            case .floor:
                return "Floor"
            case .ceiling:
                return "Ceiling"
            case .table:
                return "Table"
            case .seat:
                return "Seat"
            case .door:
                return "Door"
            case .window:
                return "Window"
            default:
                return "Wall"  // Default to "Wall" if unknown
            }
        }
        return "Wall" // Always show a label even if classification isn't supported
    }
    
    /// Create the classification label entity with Apple-style capsule design
    private func createClassificationLabel(text: String, width: Float) -> ModelEntity {
        // Create a parent entity for the classification label
        let labelEntity = ModelEntity()
        
        // Create a capsule shape for Apple-style label
        // Size proportions for good visibility (in meters)
        let labelWidth: Float = max(0.25, min(width * 0.4, 0.5)) // Reasonable capsule width
        let labelHeight: Float = 0.08 // Height that fits text well
        let labelDepth: Float = 0.02 // Thick enough to be visible
        
        // Create the pill/capsule shaped background with rounded ends
        let capsuleMesh = MeshResource.generateBox(
            width: labelWidth,
            height: labelHeight,
            depth: labelDepth,
            cornerRadius: labelHeight/2 // Makes it a pill/capsule shape
        )
        
        // Get appropriate background color based on classification
        let backgroundColor = getColorForClassification(text)
        
        // Create the capsule entity with the background color
        let capsuleEntity = ModelEntity(
            mesh: capsuleMesh,
            materials: [SimpleMaterial(
                color: backgroundColor,
                isMetallic: false
            )]
        )
        
        // Add text to the center of the capsule
        // Increase font size for better readability
        let textIndicator = ModelEntity(
            mesh: .generateText(
                text,
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.08, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            ),
            materials: [SimpleMaterial(color: .white, isMetallic: false)]
        )
        
        // Position the text slightly in front of the capsule
        textIndicator.position = [0, 0, labelDepth/2 + 0.005]
        
        // Scale the text to fit nicely within the capsule
        textIndicator.scale = [0.7, 0.7, 0.7]
        
        // Add the text to the capsule
        capsuleEntity.addChild(textIndicator)
        
        // Add the capsule to the parent entity
        labelEntity.addChild(capsuleEntity)
        
        // ADD THIS: Make the label always face the camera (billboard component)
        // This will ensure the label is correctly oriented regardless of wall rotation
        if #available(iOS 18.0, *) {
            labelEntity.components.set(BillboardComponent())
        } else {
            // Fallback on earlier versions
            // Instead of BillboardComponent, correct the orientation manually
            // This rotates the label to match the inverse of the wall's rotation
            // so that it appears upright in world space
            let wallRotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
            let correctionRotation = wallRotation.inverse
            
            labelEntity.transform = Transform(
                scale: [1, 1, 1],
                rotation: correctionRotation,
                translation: [0, 0, 0]
            )
        }
        
        return labelEntity
    }
    
    /// Get an appropriate color for a classification type
    private func getColorForClassification(_ classification: String) -> UIColor {
        switch classification.lowercased() {
        case "wall":
            return UIColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8) // Bright blue
        case "floor":
            return UIColor(red: 0.0, green: 0.7, blue: 0.3, alpha: 0.8) // Green
        case "ceiling":
            return UIColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.8) // Purple
        case "table":
            return UIColor(red: 0.8, green: 0.6, blue: 0.0, alpha: 0.8) // Orange
        case "seat":
            return UIColor(red: 0.7, green: 0.3, blue: 0.5, alpha: 0.8) // Pink
        case "door":
            return UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 0.8) // Red
        case "window":
            return UIColor(red: 0.0, green: 0.8, blue: 0.8, alpha: 0.8) // Cyan
        default:
            return UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.8) // Gray
        }
    }
    
    // MARK: - Visualization Methods

    /// Set up visualization for the detected wall
    /// - Parameter scene: The RealityKit scene to add the entity to
    func setupVisualization(in scene: RealityKit.Scene? = nil) {
        // Get wall dimensions from anchor
        let width = anchor.extent.x
        let height = 2.4  // Standard wall height in meters
        
        // Create an anchor entity to position the wall
        let anchorEntity = AnchorEntity(anchor: anchor)
        
        // 1) Create a simple unlit material for the wall
        var unlitMaterial = SimpleMaterial(color: .white, roughness: 0, isMetallic: false)
//        unlitMaterial.lightingModel = .unlit  // <-- Important to keep it from turning gray
        
        // Generate a plane mesh
        let wallMesh = MeshResource.generatePlane(width: width, height: Float(height))
        
        // Create the wall entity
        let wallEntity = ModelEntity(mesh: wallMesh, materials: [unlitMaterial])
        
        // Create a border entity (same as before)
        let borderEntity = createBorderMesh(width: width, height: Float(height), thickness: 0.01)
        
        // Rotate the plane to stand upright
        let rotation = simd_quatf(angle: -.pi/2, axis: [1, 0, 0])
        wallEntity.transform = Transform(rotation: rotation)
        
        // Slightly offset the border so it doesn’t Z-fight
        borderEntity.transform = Transform(rotation: rotation,
                                           translation: [0, 0, -0.001])
        
        // Add both to the anchor
        anchorEntity.addChild(wallEntity)
        anchorEntity.addChild(borderEntity)
        
        // 2) Always add a label and ensure it’s in front of the plane
        let classification = getClassificationDescription(for: anchor)
        let classificationEntity = createClassificationLabel(text: classification, width: width)
        
        // Position the label in front (+Z) so it isn’t hidden behind the plane
        classificationEntity.position = [0, 0, -0.05]
        // (If you still don’t see it, try 0.1 or -0.05, depending on plane orientation)
        
        anchorEntity.addChild(classificationEntity)
        
        // Store references
        self.visualEntity = wallEntity
        self.borderEntity = borderEntity
        self.anchorEntity = anchorEntity
        
        // Add to the scene if provided
        if let scene = scene {
            scene.addAnchor(anchorEntity)
        }
        
        LogManager.shared.info(message: "Set up visualization for wall \(id)", category: "WallEntity")
    }

    
    /// Create a border mesh for wall outline
    private func createBorderMesh(width: Float, height: Float, thickness: Float) -> ModelEntity {
        // Use a thin box for each edge instead of lines
        let edgeThickness = thickness
        
        // Calculate positions for each edge
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        // Create border edges as separate entities
        let bottomEdge = ModelEntity(
            mesh: .generateBox(width: width, height: edgeThickness, depth: edgeThickness),
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        bottomEdge.position = [0, -halfHeight, 0]
        
        let topEdge = ModelEntity(
            mesh: .generateBox(width: width, height: edgeThickness, depth: edgeThickness),
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        topEdge.position = [0, halfHeight, 0]
        
        let leftEdge = ModelEntity(
            mesh: .generateBox(width: edgeThickness, height: height, depth: edgeThickness),
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        leftEdge.position = [-halfWidth, 0, 0]
        
        let rightEdge = ModelEntity(
            mesh: .generateBox(width: edgeThickness, height: height, depth: edgeThickness),
            materials: [SimpleMaterial(color: .black, isMetallic: false)]
        )
        rightEdge.position = [halfWidth, 0, 0]
        
        // Create a parent entity to hold all edges
        let borderEntity = ModelEntity()
        
        // Add all edges to the parent
        borderEntity.addChild(bottomEdge)
        borderEntity.addChild(topEdge)
        borderEntity.addChild(leftEdge)
        borderEntity.addChild(rightEdge)
        
        return borderEntity
    }
    
    /// Update the visualization geometry when anchor dimensions change
    private func updateVisualizationGeometry() {
        guard let visualEntity = visualEntity, let borderEntity = borderEntity else {
            LogManager.shared.warning("Cannot update visualization geometry, entities not created yet", category: "WallEntity")
            return
        }
        
        // Get updated dimensions
        let width = anchor.extent.x
        let height = 2.4  // Standard wall height
        
        // Update main wall plane
        let wallMesh = MeshResource.generatePlane(width: width, height: Float(height))
        visualEntity.model?.mesh = wallMesh
        
        // Find the edge entities using index (assuming the order from createBorderMesh)
        guard borderEntity.children.count >= 4 else { return }
        
        // Calculate half dimensions
        let halfWidth = width / 2
        let halfHeight = Float(height) / 2
        
        // Update border geometry (assuming children order: bottom, top, left, right)
        if let bottomEdge = borderEntity.children[0] as? ModelEntity {
            bottomEdge.model?.mesh = .generateBox(width: width, height: 0.01, depth: 0.01)
            bottomEdge.position = [0, -halfHeight, 0]
        }
        
        if let topEdge = borderEntity.children[1] as? ModelEntity {
            topEdge.model?.mesh = .generateBox(width: width, height: 0.01, depth: 0.01)
            topEdge.position = [0, halfHeight, 0]
        }
        
        if let leftEdge = borderEntity.children[2] as? ModelEntity {
            leftEdge.model?.mesh = .generateBox(width: 0.01, height: Float(height), depth: 0.01)
            leftEdge.position = [-halfWidth, 0, 0]
        }
        
        if let rightEdge = borderEntity.children[3] as? ModelEntity {
            rightEdge.model?.mesh = .generateBox(width: 0.01, height: Float(height), depth: 0.01)
            rightEdge.position = [halfWidth, 0, 0]
        }
        
        // Update classification label if it exists
        if let anchorEntity = anchorEntity {
            // Find the classification entity (assumed to be the last child)
            if anchorEntity.children.count > 2 {
                let classificationIndex = anchorEntity.children.count - 1
                if let classificationEntity = anchorEntity.children[classificationIndex] as? ModelEntity {
                    // Update position to keep the label centered on the wall
                    classificationEntity.position = [0, 0, -0.05]
                    
                    // Update classification text if needed
                    let newClassification = getClassificationDescription(for: anchor)
                    
                    // If the first child has children (capsule with text)
                    if !classificationEntity.children.isEmpty,
                       let capsuleEntity = classificationEntity.children[0] as? ModelEntity {
                        
                        // Check if we need to update the classification text
                        if let firstChild = capsuleEntity.children.first,
                           firstChild.name != newClassification {
                            // Remove existing capsule and add a new one with updated text
                            capsuleEntity.removeFromParent()
                            let updatedClassificationEntity = createClassificationLabel(text: newClassification, width: width)
                            classificationEntity.addChild(updatedClassificationEntity.children[0])
                        }
                    }
                }
            }
        }
    }
    
    /// Update the visualization based on current state
    func updateVisualization() {
        guard let visualEntity = visualEntity, let borderEntity = borderEntity else {
            LogManager.shared.warning("Attempted to update visualization for wall \(id) but visual entities don't exist", category: "WallEntity")
            return
        }
        
        // Ensure we have the border edges
        guard borderEntity.children.count >= 4 else { return }
        
        // Get the border edges
        let borderEdges = borderEntity.children.compactMap { $0 as? ModelEntity }
        
        // Update wall material based on selection state and color
        if isSelected {
            // Selected wall has a blue highlight with some transparency
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor.systemBlue.withAlphaComponent(0.25))
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.7)
            visualEntity.model?.materials = [material]
            
            // Make border more prominent when selected
            for edge in borderEdges {
                edge.model?.materials = [SimpleMaterial(color: .systemBlue, isMetallic: false)]
            }
        }
        else if let color = currentColor {
            // Apply user's color with appropriate transparency
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color.withAlphaComponent(0.35))
            
            // Apply finish properties
            let finishProps = paintFinish.materialProperties
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: finishProps.roughness)
            material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: finishProps.metallic)
            visualEntity.model?.materials = [material]
            
            // Use a slightly darker version of the same color for border
            let darkerColor = color.darker(by: 0.3)
            for edge in borderEdges {
                edge.model?.materials = [SimpleMaterial(color: darkerColor, isMetallic: false)]
            }
        }
        else {
            // MODIFIED: Default unselected wall now appears as a more neutral off-white
            var material = PhysicallyBasedMaterial()
            material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.8))
            material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.8)
            material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.0)
            visualEntity.model?.materials = [material]
            
            // Default border is black
            for edge in borderEdges {
                edge.model?.materials = [SimpleMaterial(color: .black, isMetallic: false)]
            }
        }
    }
}

// MARK: - Helper Extensions

extension SIMD4 {
    /// Extract the XYZ components of a SIMD4
    var xyz: SIMD3<Scalar> {
        return SIMD3(x: self.x, y: self.y, z: self.z)
    }
}

extension UIColor {
    /// Create a darker version of this color
    func darker(by percentage: CGFloat = 0.2) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return UIColor(
            red: max(r - percentage, 0),
            green: max(g - percentage, 0),
            blue: max(b - percentage, 0),
            alpha: a
        )
    }
    
    /// Create a lighter version of this color
    func lighter(by percentage: CGFloat = 0.2) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        return UIColor(
            red: min(r + percentage, 1),
            green: min(g + percentage, 1),
            blue: min(b + percentage, 1),
            alpha: a
        )
    }
}
