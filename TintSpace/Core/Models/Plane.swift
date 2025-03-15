//
//  Plane.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/14/25.
//

//
//  Plane.swift
//  TintSpace
//

import ARKit
import SceneKit

/// Convenience class for visualizing plane extent and geometry
class Plane: SCNNode {
    
    // MARK: - Properties
    
    /// Node containing the mesh that visualizes the estimated shape of the plane
    let meshNode: SCNNode
    
    /// Node that visualizes the plane's bounding rectangle
    let extentNode: SCNNode
    
    /// Node that displays the plane's classification (floor, wall, etc.)
    var classificationNode: SCNNode?
    
    // MARK: - Initialization
    
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView) {
        // Create a mesh to visualize the estimated shape of the plane
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!)
            else { fatalError("Can't create plane geometry") }
        meshGeometry.update(from: anchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        
        // Create a node to visualize the plane's bounding rectangle
        let extentPlane: SCNPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        extentNode = SCNNode(geometry: extentPlane)
        extentNode.simdPosition = anchor.center
        
        // `SCNPlane` is vertically oriented in its local coordinate space, so
        // rotate it to match the orientation of `ARPlaneAnchor`
        extentNode.eulerAngles.x = -.pi / 2
        
        super.init()
        
        self.setupMeshVisualStyle(forPlaneType: anchor.alignment)
        self.setupExtentVisualStyle(forPlaneType: anchor.alignment)
        
        // Add the plane extent and plane geometry as child nodes so they appear in the scene
        addChildNode(meshNode)
        addChildNode(extentNode)
        
        // Display the plane's classification, if supported on the device
        if #available(iOS 12.0, *), ARPlaneAnchor.isClassificationSupported {
            let classification = anchor.classification.description
            let textNode = self.makeTextNode(classification)
            classificationNode = textNode
            // Change the pivot of the text node to its center
            textNode.centerAlign()
            // Add the classification node as a child node so that it displays the classification
            extentNode.addChildNode(textNode)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Visual Styling
    
    /// Set up the visual style for the mesh
    private func setupMeshVisualStyle(forPlaneType planeAlignment: ARPlaneAnchor.Alignment) {
        // Make the plane visualization semitransparent
        meshNode.opacity = 0.25
        
        // Use color and blend mode to make planes stand out
        guard let material = meshNode.geometry?.firstMaterial
            else { fatalError("ARSCNPlaneGeometry always has one material") }
        
        // Set different colors based on plane alignment (horizontal vs vertical)
        if planeAlignment == .vertical {
            // Use tint color for vertical planes (walls)
            material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.8)
        } else {
            // Use gray for horizontal planes (floors, tables, etc.)
            material.diffuse.contents = UIColor.lightGray.withAlphaComponent(0.8)
        }
    }
    
    /// Set up the visual style for the plane extent
    private func setupExtentVisualStyle(forPlaneType planeAlignment: ARPlaneAnchor.Alignment) {
        // Make the extent visualization semitransparent
        extentNode.opacity = 0.6
        
        guard let material = extentNode.geometry?.firstMaterial
            else { fatalError("SCNPlane always has one material") }
        
        // Set different colors based on plane alignment
        if planeAlignment == .vertical {
            // Use tint color for vertical planes (walls)
            material.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.9)
        } else {
            // Use gray for horizontal planes (floors, tables, etc.)
            material.diffuse.contents = UIColor.lightGray.withAlphaComponent(0.9)
        }
        
        // For wireframe effect
        material.isDoubleSided = true
        
        // Simple wireframe effect without shader
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(extentNode.geometry!.boundingBox.max.x - extentNode.geometry!.boundingBox.min.x),
                                                              Float(extentNode.geometry!.boundingBox.max.z - extentNode.geometry!.boundingBox.min.z), 1)
    }
    
    /// Create a text node to display plane classification
    private func makeTextNode(_ text: String) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 1)
        textGeometry.font = UIFont(name: "Futura", size: 75)
        
        let textNode = SCNNode(geometry: textGeometry)
        // Scale down the size of the text
        textNode.simdScale = SIMD3<Float>(repeating: 0.0005)
        
        return textNode
    }
}

// MARK: - Helper Extensions

@available(iOS 12.0, *)
extension ARPlaneAnchor.Classification {
    var description: String {
        switch self {
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
        case .none(.unknown):
            return "Unknown"
        default:
            return ""
        }
    }
}

extension SCNNode {
    func centerAlign() {
        let (min, max) = boundingBox
        let extents = SIMD3<Float>(max) - SIMD3<Float>(min)
        simdPivot = float4x4(translation: ((extents / 2) + SIMD3<Float>(min)))
    }
}

extension float4x4 {
    init(translation vector: SIMD3<Float>) {
        self.init(SIMD4<Float>(1, 0, 0, 0),
                  SIMD4<Float>(0, 1, 0, 0),
                  SIMD4<Float>(0, 0, 1, 0),
                  SIMD4<Float>(vector.x, vector.y, vector.z, 1))
    }
}
