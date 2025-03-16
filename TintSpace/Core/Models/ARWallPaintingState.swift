//
//  ARWallPaintingState.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/16/25.
//

// ARWallPaintingState.swift
import ARKit
import Foundation

/// Represents the current state of the AR wall painting experience
enum ARWallPaintingState: Equatable {
    case initializing
    case scanning            // Looking for walls
    case wallsDetected       // Found at least one wall
    case wallSelected        // User has selected a wall
    case colorApplied        // Color has been applied to a wall
    case limited(ARCamera.TrackingState.Reason)  // Limited tracking
    case failed(Error)       // Session failed
    case paused              // Session paused
    
    // Custom Equatable implementation to handle Error cases
    static func == (lhs: ARWallPaintingState, rhs: ARWallPaintingState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.scanning, .scanning),
             (.wallsDetected, .wallsDetected),
             (.wallSelected, .wallSelected),
             (.colorApplied, .colorApplied),
             (.paused, .paused):
            return true
        case (.limited(let lhsReason), .limited(let rhsReason)):
            return lhsReason == rhsReason
        case (.failed, .failed):
            // Just check if both are error states, not the specific error
            return true
        default:
            return false
        }
    }
}

/// Protocol for receiving AR session events
protocol ARSessionManagerDelegate: AnyObject {
    /// Called when the AR session state changes
    func arSessionManager(_ manager: ARSessionManager, didChangeState state: ARWallPaintingState)
    
    /// Called when a vertical plane (potential wall) is detected
    func arSessionManager(_ manager: ARSessionManager, didDetectWall anchor: ARPlaneAnchor)
    
    /// Called when a vertical plane (potential wall) is updated
    func arSessionManager(_ manager: ARSessionManager, didUpdateWall anchor: ARPlaneAnchor)
    
    /// Called when a vertical plane (potential wall) is removed
    func arSessionManager(_ manager: ARSessionManager, didRemoveWall anchor: ARPlaneAnchor)
    
    /// Called when an error occurs in the AR session
    func arSessionManager(_ manager: ARSessionManager, didEncounterError error: Error)
}

// Default implementations to make adoption easier
extension ARSessionManagerDelegate {
    func arSessionManager(_ manager: ARSessionManager, didUpdateWall anchor: ARPlaneAnchor) {}
    func arSessionManager(_ manager: ARSessionManager, didRemoveWall anchor: ARPlaneAnchor) {}
}
