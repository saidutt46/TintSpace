//
//  WallPlane.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation
import ARKit
import RealityKit

/// Represents a detected wall plane in the AR scene
struct WallPlane: Identifiable {
    // Unique identifier for the wall
    let id: UUID
    
    // Reference to the ARKit anchor for this wall
    let anchor: ARPlaneAnchor
    
    // Reference to the RealityKit entity representing this wall
    var entity: ModelEntity?
    
    // Current color applied to the wall (if any)
    var appliedColor: PaintColor?
    
    // Current paint finish applied to the wall (if any)
    var appliedFinish: PaintFinish = .matte
    
    // Is this wall currently selected by the user
    var isSelected: Bool = false
    
    // Wall dimensions - using newer API for iOS 16+
    var width: Float {
        return anchor.planeExtent.width
    }
    
    var height: Float {
        return anchor.planeExtent.height
    }
    
    // Wall position
    var center: SIMD3<Float> {
        return anchor.transform.columns.3.xyz
    }
    
    // Convenience initializer
    init(anchor: ARPlaneAnchor) {
        self.id = UUID()
        self.anchor = anchor
    }
}

// Helper extension to get xyz values from a SIMD4
extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        return SIMD3(x: self.x, y: self.y, z: self.z)
    }
}
