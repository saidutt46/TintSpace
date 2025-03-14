//
//  DeviceCapabilityManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation
import UIKit
import ARKit
import Metal
import AVFoundation
import Photos
import CoreMotion
import CoreLocation

/// A comprehensive device capability manager that assesses and reports on the device's hardware and software capabilities
final class DeviceCapabilityManager {
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    static let shared = DeviceCapabilityManager()
    
    // MARK: - Properties
    
    /// The device's model identifier (e.g., "iPhone13,4" for iPhone 12 Pro Max)
    let deviceModel: String
    
    /// The marketing name of the device (e.g., "iPhone 12 Pro Max")
    let deviceName: String
    
    /// The OS version (e.g., "iOS 16.0")
    let osVersion: String
    
    /// Screen properties
    let screenProperties: ScreenProperties
    
    /// System memory information
    let memoryInfo: MemoryInfo
    
    /// Device performance tier estimation
    let performanceTier: PerformanceTier
    
    /// AR capabilities
    let arCapabilities: ARCapabilities
    
    /// Sensor capabilities
    let sensorCapabilities: SensorCapabilities
    
    /// Camera capabilities
    let cameraCapabilities: CameraCapabilities
    
    /// GPU capabilities
    let gpuCapabilities: GPUCapabilities
    
    /// Permission statuses
    private(set) var permissionStatuses = PermissionStatuses()
    
    // MARK: - Initialization
    
    /// Initialize and assess all device capabilities
    private init() {
        // Get basic device info
        deviceModel = Self.getDeviceModel()
        deviceName = Self.getDeviceMarketingName(from: deviceModel)
        osVersion = UIDevice.current.systemVersion
        
        // Get screen properties
        screenProperties = Self.getScreenProperties()
        
        // Get memory info
        memoryInfo = Self.getMemoryInfo()
        
        // Determine performance tier
        performanceTier = Self.estimatePerformanceTier(deviceModel: deviceModel)
        
        // Check AR capabilities
        arCapabilities = Self.checkARCapabilities()
        
        // Check sensor capabilities
        sensorCapabilities = Self.checkSensorCapabilities()
        
        // Check camera capabilities
        cameraCapabilities = Self.checkCameraCapabilities()
        
        // Check GPU capabilities
        gpuCapabilities = Self.checkGPUCapabilities()
        
        // Log device capabilities
        logCapabilities()
    }
    
    // MARK: - Device Models
    
    /// Represents the performance tier of the device
    enum PerformanceTier: String {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case veryHigh = "Very High"
        
        /// Whether the device meets minimum requirements for the app
        var meetsMinimumRequirements: Bool {
            return self != .low
        }
        
        /// Whether advanced features should be enabled on this device
        var enableAdvancedFeatures: Bool {
            return self == .high || self == .veryHigh
        }
    }
    
    /// Represents screen properties
    struct ScreenProperties {
        let width: CGFloat
        let height: CGFloat
        let scale: CGFloat
        let nativeScale: CGFloat
        let isNotched: Bool
        let hasDynamicIsland: Bool
        let refreshRate: Float // in Hz
        
        /// Whether the device has a ProMotion display (120Hz)
        var hasProMotion: Bool {
            return refreshRate > 90
        }
    }
    
    /// Represents system memory information
    struct MemoryInfo {
        let totalRAM: UInt64 // in bytes
        let availableRAM: UInt64 // in bytes
        
        /// RAM in gigabytes, formatted to one decimal place
        var formattedRAM: String {
            let gbValue = Double(totalRAM) / 1_073_741_824 // Convert bytes to GB
            return String(format: "%.1f GB", gbValue)
        }
    }
    
    /// Represents AR capabilities
    struct ARCapabilities {
        let worldTrackingSupported: Bool
        let peopleOcclusionSupported: Bool
        let sceneReconstructionSupported: Bool
        let lidarPresent: Bool
        let objectPlacementSupported: Bool
        let faceTrackingSupported: Bool
        let bodyTrackingSupported: Bool
        let imageTrackingSupported: Bool
        let environmentTexturingSupported: Bool
        let collaborativeSessionsSupported: Bool
        let geoTrackingSupported: Bool
        
        /// Whether the device has sufficient AR capabilities for the app
        var hasSufficientCapabilities: Bool {
            return worldTrackingSupported && objectPlacementSupported
        }
    }
    
    /// Represents sensor capabilities
    struct SensorCapabilities {
        let accelerometer: Bool
        let gyroscope: Bool
        let magnetometer: Bool
        let motionProcessing: Bool
        let barometer: Bool
        let locationServices: Bool
        let proximityMonitoring: Bool
        
        /// Whether the device has basic motion sensors (accelerometer and gyroscope)
        var hasBasicMotionSensors: Bool {
            return accelerometer && gyroscope
        }
    }
    
    /// Represents camera capabilities
    struct CameraCapabilities {
        let hasBackCamera: Bool
        let hasFrontCamera: Bool
        let hasWideAngleCamera: Bool
        let hasTelephotoCamera: Bool
        let hasUltraWideCamera: Bool
        let maxVideoResolution: String
        let hasFlash: Bool
        
        /// Whether the device has sufficient camera capabilities for AR
        var hasSufficientCameraForAR: Bool {
            return hasBackCamera
        }
    }
    
    /// Represents GPU capabilities
    struct GPUCapabilities {
        let gpuName: String
        let supportsMetal: Bool
        let maxTextureSize: Int
        let supportsHDR: Bool
        let supportsMSAA: Bool
        
        /// Whether the GPU has sufficient capabilities for the app
        var hasSufficientCapabilities: Bool {
            return supportsMetal
        }
    }
    
    /// Represents permission statuses
    struct PermissionStatuses {
        var camera: PermissionStatus = .unknown
        var photoLibrary: PermissionStatus = .unknown
        var location: PermissionStatus = .unknown
        var microphone: PermissionStatus = .unknown
        
        /// Permission status enum
        enum PermissionStatus: String {
            case unknown = "Unknown"
            case notDetermined = "Not Determined"
            case denied = "Denied"
            case authorized = "Authorized"
            case restricted = "Restricted"
            case limited = "Limited"
        }
    }
    
    // MARK: - Capability Assessment Methods
    
    /// Gets the device model identifier (e.g., "iPhone13,4")
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let model = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return model
    }
    
    /// Gets the marketing name from the device model
    private static func getDeviceMarketingName(from model: String) -> String {
        // This is a simplified mapping - a real implementation would be more comprehensive
        let deviceMapping: [String: String] = [
            // iPhones
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,5": "iPhone 13",
            "iPhone14,4": "iPhone 13 Mini",
            "iPhone13,4": "iPhone 12 Pro Max",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,2": "iPhone 12",
            "iPhone13,1": "iPhone 12 Mini",
            "iPhone12,5": "iPhone 11 Pro Max",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,1": "iPhone 11",
            "iPhone15,4": "iPhone 14",
            "iPhone15,5": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            
            // iPads
            "iPad8,1": "iPad Pro 11-inch (1st gen)",
            "iPad8,2": "iPad Pro 11-inch (1st gen)",
            "iPad8,3": "iPad Pro 11-inch (1st gen)",
            "iPad8,4": "iPad Pro 11-inch (1st gen)",
            "iPad8,5": "iPad Pro 12.9-inch (3rd gen)",
            "iPad8,6": "iPad Pro 12.9-inch (3rd gen)",
            "iPad8,7": "iPad Pro 12.9-inch (3rd gen)",
            "iPad8,8": "iPad Pro 12.9-inch (3rd gen)",
            "iPad8,9": "iPad Pro 11-inch (2nd gen)",
            "iPad8,10": "iPad Pro 11-inch (2nd gen)",
            "iPad8,11": "iPad Pro 12.9-inch (4th gen)",
            "iPad8,12": "iPad Pro 12.9-inch (4th gen)",
            "iPad13,1": "iPad Air (4th gen)",
            "iPad13,2": "iPad Air (4th gen)",
            "iPad13,4": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,5": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,6": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,7": "iPad Pro 12.9-inch (5th gen)",
            "iPad13,8": "iPad Pro 11-inch (3rd gen)",
            "iPad13,9": "iPad Pro 11-inch (3rd gen)",
            "iPad13,10": "iPad Pro 11-inch (3rd gen)",
            "iPad13,11": "iPad Pro 11-inch (3rd gen)"
        ]
        
        return deviceMapping[model] ?? "Unknown \(UIDevice.current.model)"
    }
    
    /// Gets screen properties
    private static func getScreenProperties() -> ScreenProperties {
        let screen = UIScreen.main
        let bounds = screen.bounds
        
        // Check for notch or dynamic island
        let hasNotch = Self.deviceHasNotch()
        let hasDynamicIsland = hasNotch && getDeviceModel().contains("iPhone15") || getDeviceModel().contains("iPhone16")
        
        // Attempt to determine refresh rate
        let refreshRate: Float = 60.0  // Default to 60Hz
        // A real implementation would use CADisplayLink to measure actual refresh rate
        
        return ScreenProperties(
            width: bounds.width,
            height: bounds.height,
            scale: screen.scale,
            nativeScale: screen.nativeScale,
            isNotched: hasNotch,
            hasDynamicIsland: hasDynamicIsland,
            refreshRate: refreshRate
        )
    }
    
    /// Determines if the device has a notch
    private static func deviceHasNotch() -> Bool {
        guard #available(iOS 11.0, *) else { return false }
        let window = UIApplication.shared.windows.first
        let safeAreaInsets = window?.safeAreaInsets
        return safeAreaInsets?.top ?? 0 > 20
    }
    
    /// Gets memory information
    private static func getMemoryInfo() -> MemoryInfo {
        let totalRAM = ProcessInfo.processInfo.physicalMemory
        
        // Getting available RAM is not directly possible in iOS, but we can estimate it
        // This would require a more sophisticated implementation in a real app
        // For now, we'll just estimate 40% of total RAM is available
        let estimatedAvailableRAM = UInt64(Double(totalRAM) * 0.4)
        
        return MemoryInfo(totalRAM: totalRAM, availableRAM: estimatedAvailableRAM)
    }
    
    /// Estimates the performance tier based on device model
    private static func estimatePerformanceTier(deviceModel: String) -> PerformanceTier {
        // A more comprehensive implementation would include many more device models
        
        // iPhone 11 and newer high-end models = very high
        if deviceModel.contains("iPhone14") || deviceModel.contains("iPhone15") || deviceModel.contains("iPhone16") ||
           deviceModel.contains("iPhone13") || deviceModel.contains("iPhone12,3") || deviceModel.contains("iPhone12,5") {
            return .veryHigh
        }
        
        // iPhone 11 base model, XR, XS, X = high
        if deviceModel.contains("iPhone12,1") || deviceModel.contains("iPhone11") || deviceModel.contains("iPhone10") {
            return .high
        }
        
        // iPhone 8, 7 Plus, etc. = medium
        if deviceModel.contains("iPhone9") || deviceModel.contains("iPhone8") {
            return .medium
        }
        
        // iPhone 6s, SE 1st gen, etc. = low
        return .low
    }
    
    /// Checks AR capabilities
    private static func checkARCapabilities() -> ARCapabilities {
        // Check if ARKit is available
        let worldTrackingSupported = ARWorldTrackingConfiguration.isSupported
        
        // Check if people occlusion is supported
        let peopleOcclusionSupported = ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth)
        
        // Check if scene reconstruction is supported
        let sceneReconstructionSupported: Bool
        if #available(iOS 13.4, *) {
            sceneReconstructionSupported = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        } else {
            sceneReconstructionSupported = false
        }
        
        // Check other AR capabilities
        let faceTrackingSupported = ARFaceTrackingConfiguration.isSupported
        
        // Body tracking requires checking ARBodyTrackingConfiguration which is available on newer iOS versions
        let bodyTrackingSupported: Bool
        if #available(iOS 13.0, *) {
            bodyTrackingSupported = ARBodyTrackingConfiguration.isSupported
        } else {
            bodyTrackingSupported = false
        }
        
        // Determine if LiDAR is present - inferred from scene reconstruction support
        let lidarPresent = sceneReconstructionSupported
        
        // Check if ARKit supports image tracking
        let imageTrackingSupported = true // Simplification, it's supported on all ARKit-capable devices
        
        // Environment texturing
        let environmentTexturingSupported = true // Simplification, available on ARKit 2+
        
        // Collaborative sessions
        let collaborativeSessionsSupported: Bool
        if #available(iOS 13.0, *) {
            collaborativeSessionsSupported = true
        } else {
            collaborativeSessionsSupported = false
        }
        
        // Geo tracking (for AR anchors based on real-world coordinates)
        let geoTrackingSupported: Bool
        if #available(iOS 14.0, *) {
            geoTrackingSupported = ARGeoTrackingConfiguration.isSupported
        } else {
            geoTrackingSupported = false
        }
        
        return ARCapabilities(
            worldTrackingSupported: worldTrackingSupported,
            peopleOcclusionSupported: peopleOcclusionSupported,
            sceneReconstructionSupported: sceneReconstructionSupported,
            lidarPresent: lidarPresent,
            objectPlacementSupported: worldTrackingSupported,
            faceTrackingSupported: faceTrackingSupported,
            bodyTrackingSupported: bodyTrackingSupported,
            imageTrackingSupported: imageTrackingSupported,
            environmentTexturingSupported: environmentTexturingSupported,
            collaborativeSessionsSupported: collaborativeSessionsSupported,
            geoTrackingSupported: geoTrackingSupported
        )
    }
    
    /// Checks sensor capabilities
    private static func checkSensorCapabilities() -> SensorCapabilities {
        let motionManager = CMMotionManager()
        
        // Check device sensors
        let hasAccelerometer = motionManager.isAccelerometerAvailable
        let hasGyroscope = motionManager.isGyroAvailable
        let hasMagnetometer = motionManager.isMagnetometerAvailable
        let hasMotionProcessing = motionManager.isDeviceMotionAvailable
        
        // Check barometer
        let hasBarometer = CMAltimeter.isRelativeAltitudeAvailable()
        
        // Check location services - with warning suppression
        #if DEBUG
        // Suppress warning in debug mode - we know it's not ideal but it's just for diagnostics
        let hasLocationServices = CLLocationManager.locationServicesEnabled()
        #else
        // In production, be more conservative and default to false
        let hasLocationServices = false
        #endif
        
        // Check proximity monitoring
        let hasProximity = UIDevice.current.isProximityMonitoringEnabled
        
        return SensorCapabilities(
            accelerometer: hasAccelerometer,
            gyroscope: hasGyroscope,
            magnetometer: hasMagnetometer,
            motionProcessing: hasMotionProcessing,
            barometer: hasBarometer,
            locationServices: hasLocationServices,
            proximityMonitoring: hasProximity
        )
    }
    
    /// Checks camera capabilities
    private static func checkCameraCapabilities() -> CameraCapabilities {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInWideAngleCamera,
                .builtInTelephotoCamera,
                .builtInUltraWideCamera
            ],
            mediaType: .video,
            position: .unspecified
        )
        
        // Check camera types
        var hasBackCamera = false
        var hasFrontCamera = false
        var hasWideAngleCamera = false
        var hasTelephotoCamera = false
        var hasUltraWideCamera = false
        var hasFlash = false
        
        for device in discovery.devices {
            if device.position == .back {
                hasBackCamera = true
                hasFlash = device.hasFlash
                
                if device.deviceType == .builtInWideAngleCamera {
                    hasWideAngleCamera = true
                } else if device.deviceType == .builtInTelephotoCamera {
                    hasTelephotoCamera = true
                } else if device.deviceType == .builtInUltraWideCamera {
                    hasUltraWideCamera = true
                }
            } else if device.position == .front {
                hasFrontCamera = true
            }
        }
        
        // Determine max video resolution (simplified)
        let maxVideoResolution = "4K" // Most modern devices support 4K; a real implementation would check formats
        
        return CameraCapabilities(
            hasBackCamera: hasBackCamera,
            hasFrontCamera: hasFrontCamera,
            hasWideAngleCamera: hasWideAngleCamera,
            hasTelephotoCamera: hasTelephotoCamera,
            hasUltraWideCamera: hasUltraWideCamera,
            maxVideoResolution: maxVideoResolution,
            hasFlash: hasFlash
        )
    }
    
    /// Checks GPU capabilities
    private static func checkGPUCapabilities() -> GPUCapabilities {
        // Check Metal support
        let supportsMetal = MTLCreateSystemDefaultDevice() != nil
        
        // Get GPU name and capabilities
        var gpuName = "Unknown GPU"
        var maxTextureSize = 4096 // Default conservative value
        var supportsHDR = false
        var supportsMSAA = false
        
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
            
            // Use maxBufferLength as a proxy for capability
            // In a real implementation, you might want to use a different property
            // or calculate an appropriate value
            maxTextureSize = Int(device.maxBufferLength / 1024) // Convert to KB for a reasonable texture size metric
            
            // Limit to a reasonable max texture size (most devices support at least 4096)
            maxTextureSize = min(maxTextureSize, 16384)
            
            supportsMSAA = true // Simplification, most Metal devices support MSAA
            
            // Check for HDR support
            if #available(iOS 13.0, *) {
                supportsHDR = true // Simplified; in reality, need more checks
            }
        }
        
        return GPUCapabilities(
            gpuName: gpuName,
            supportsMetal: supportsMetal,
            maxTextureSize: maxTextureSize,
            supportsHDR: supportsHDR,
            supportsMSAA: supportsMSAA
        )
    }
    
    // MARK: - Permission Status Checking
    
    /// Checks and updates permission statuses
    func checkPermissionStatuses(completion: @escaping () -> Void) {
        let group = DispatchGroup()
        
        // Check camera permission
        group.enter()
        checkCameraPermission { status in
            self.permissionStatuses.camera = status
            group.leave()
        }
        
        // Check photo library permission
        group.enter()
        checkPhotoLibraryPermission { status in
            self.permissionStatuses.photoLibrary = status
            group.leave()
        }
        
        // Check location permission
        group.enter()
        checkLocationPermission { status in
            self.permissionStatuses.location = status
            group.leave()
        }
        
        // Check microphone permission
        group.enter()
        checkMicrophonePermission { status in
            self.permissionStatuses.microphone = status
            group.leave()
        }
        
        // When all checks are done
        group.notify(queue: .main) {
            self.logPermissionStatuses()
            completion()
        }
    }
    
    /// Check camera permission status
    private func checkCameraPermission(completion: @escaping (PermissionStatuses.PermissionStatus) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(.authorized)
        case .denied:
            completion(.denied)
        case .restricted:
            completion(.restricted)
        case .notDetermined:
            completion(.notDetermined)
        @unknown default:
            completion(.unknown)
        }
    }
    
    /// Check photo library permission status
    private func checkPhotoLibraryPermission(completion: @escaping (PermissionStatuses.PermissionStatus) -> Void) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            completion(.authorized)
        case .denied:
            completion(.denied)
        case .restricted:
            completion(.restricted)
        case .notDetermined:
            completion(.notDetermined)
        case .limited:
            completion(.limited)
        @unknown default:
            completion(.unknown)
        }
    }
    
    /// Check location permission status
    private func checkLocationPermission(completion: @escaping (PermissionStatuses.PermissionStatus) -> Void) {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            completion(.authorized)
        case .denied:
            completion(.denied)
        case .restricted:
            completion(.restricted)
        case .notDetermined:
            completion(.notDetermined)
        @unknown default:
            completion(.unknown)
        }
    }
    
    /// Check microphone permission status
    private func checkMicrophonePermission(completion: @escaping (PermissionStatuses.PermissionStatus) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(.authorized)
        case .denied:
            completion(.denied)
        case .undetermined:
            completion(.notDetermined)
        @unknown default:
            completion(.unknown)
        }
    }
    
    // MARK: - Logging
    
    /// Logs all device capabilities
    private func logCapabilities() {
        LogManager.shared.info(message: "📱 Device Capabilities Report 📱", category: "DeviceCapabilities")
        
        // Log device info
        LogManager.shared.info(message: "Device: \(deviceName) (\(deviceModel))", category: "DeviceCapabilities")
        LogManager.shared.info(message: "OS Version: iOS \(osVersion)", category: "DeviceCapabilities")
        LogManager.shared.info(message: "Performance Tier: \(performanceTier.rawValue)", category: "DeviceCapabilities")
        
        // Log screen info
        LogManager.shared.info(message: "Screen: \(Int(screenProperties.width))×\(Int(screenProperties.height)) @\(screenProperties.scale)x, Refresh Rate: \(screenProperties.refreshRate)Hz",
                            category: "DeviceCapabilities")
        LogManager.shared.info(message: "Notched: \(screenProperties.isNotched), Dynamic Island: \(screenProperties.hasDynamicIsland)",
                            category: "DeviceCapabilities")
        
        // Log memory info
        LogManager.shared.info(message: "Memory: \(memoryInfo.formattedRAM)",
                            category: "DeviceCapabilities")
        
        // Log AR capabilities
        LogManager.shared.info(message: "AR Features:", category: "DeviceCapabilities")
        LogManager.shared.info(message: "  • World Tracking: \(arCapabilities.worldTrackingSupported ? "✅" : "❌")",
                            category: "DeviceCapabilities")
        LogManager.shared.info(message: "  • People Occlusion: \(arCapabilities.peopleOcclusionSupported ? "✅" : "❌")",
                            category: "DeviceCapabilities")
        LogManager.shared.info(message: "  • Scene Reconstruction: \(arCapabilities.sceneReconstructionSupported ? "✅" : "❌")",
                            category: "DeviceCapabilities")
        LogManager.shared.info(message: "  • LiDAR: \(arCapabilities.lidarPresent ? "✅" : "❌")",
                            category: "DeviceCapabilities")
        
        // Log if the device meets requirements
        if arCapabilities.hasSufficientCapabilities && performanceTier.meetsMinimumRequirements {
            LogManager.shared.success("Device meets TintSpace requirements ✅", category: "DeviceCapabilities")
        } else {
            LogManager.shared.warning("Device may not meet TintSpace requirements ⚠️", category: "DeviceCapabilities")
        }
    }
    
    /// Logs permission statuses
    private func logPermissionStatuses() {
        LogManager.shared.info(message: "📝 Permission Statuses:", category: "Permissions")
        LogManager.shared.info(message: "  • Camera: \(permissionStatuses.camera.rawValue)",
                            category: "Permissions")
        LogManager.shared.info(message: "  • Photo Library: \(permissionStatuses.photoLibrary.rawValue)",
                            category: "Permissions")
        LogManager.shared.info(message: "  • Location: \(permissionStatuses.location.rawValue)",
                            category: "Permissions")
        LogManager.shared.info(message: "  • Microphone: \(permissionStatuses.microphone.rawValue)",
                            category: "Permissions")
    }
    
    // MARK: - Public Methods
    
    /// Determines if the device has sufficient capabilities for the app
    func deviceMeetsRequirements() -> Bool {
        return arCapabilities.hasSufficientCapabilities &&
               performanceTier.meetsMinimumRequirements &&
               cameraCapabilities.hasSufficientCameraForAR &&
               gpuCapabilities.hasSufficientCapabilities
    }
    
    /// Returns a list of missing capabilities if the device doesn't meet requirements
    func getMissingCapabilities() -> [String] {
        var missingCapabilities = [String]()
        
        if !arCapabilities.worldTrackingSupported {
            missingCapabilities.append("AR World Tracking")
        }
        
        if !performanceTier.meetsMinimumRequirements {
            missingCapabilities.append("Device Performance")
        }
        
        if !cameraCapabilities.hasSufficientCameraForAR {
            missingCapabilities.append("Camera")
        }
        
        if !gpuCapabilities.supportsMetal {
            missingCapabilities.append("Metal Support")
        }
        
        return missingCapabilities
    }
    
    /// Returns a user-friendly device capability summary
    func getCapabilitySummary() -> String {
        return """
        Device: \(deviceName)
        Performance: \(performanceTier.rawValue)
        Memory: \(memoryInfo.formattedRAM)
        AR: \(arCapabilities.worldTrackingSupported ? "Supported" : "Not Supported")
        LiDAR: \(arCapabilities.lidarPresent ? "Present" : "Not Present")
        """
    }
}

