//
//  CapabilityCheckView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import SwiftUI

struct CapabilityCheckView: View {
    // Device capabilities
    private let deviceCapabilities = DeviceCapabilityManager.shared
    
    // AR session manager
    @EnvironmentObject var arSessionManager: ARSessionManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Device Capability Check")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                // Device Info Section
                deviceInfoSection
                
                // AR Capabilities Section
                arCapabilitiesSection
                
                // Sensor Capabilities Section
                sensorCapabilitiesSection
                
                // Permission Status Section
                permissionStatusSection
                
                // Actions
                actionButtons
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            LogManager.shared.ui("CapabilityCheckView appeared", category: "UI")
            
            // Log a detailed user action for analytics
            LogManager.shared.userAction("ViewedCapabilityScreen", details: [
                "deviceModel": deviceCapabilities.deviceModel,
                "performanceTier": deviceCapabilities.performanceTier.rawValue,
                "meetsRequirements": deviceCapabilities.deviceMeetsRequirements()
            ])
        }
    }
    
    // Device Info Section
    private var deviceInfoSection: some View {
        VStack(alignment: .leading) {
            sectionHeader("Device Information")
            
            infoRow("Device", deviceCapabilities.deviceName)
            infoRow("Model", deviceCapabilities.deviceModel)
            infoRow("iOS Version", deviceCapabilities.osVersion)
            infoRow("Performance Tier", deviceCapabilities.performanceTier.rawValue)
            infoRow("Memory", deviceCapabilities.memoryInfo.formattedRAM)
            infoRow("Screen", "\(Int(deviceCapabilities.screenProperties.width))×\(Int(deviceCapabilities.screenProperties.height))")
            infoRow("Refresh Rate", "\(deviceCapabilities.screenProperties.refreshRate) Hz")
            
            // Overall status indicator
            HStack {
                Text("TintSpace Compatibility")
                    .font(.headline)
                Spacer()
                if deviceCapabilities.deviceMeetsRequirements() {
                    Text("Compatible ✅")
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                } else {
                    Text("Limited Compatibility ⚠️")
                        .foregroundColor(.orange)
                        .fontWeight(.bold)
                }
            }
            .padding(.vertical, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // AR Capabilities Section
    private var arCapabilitiesSection: some View {
        VStack(alignment: .leading) {
            sectionHeader("AR Capabilities")
            
            capabilityRow("World Tracking", deviceCapabilities.arCapabilities.worldTrackingSupported)
            capabilityRow("People Occlusion", deviceCapabilities.arCapabilities.peopleOcclusionSupported)
            capabilityRow("LiDAR Sensor", deviceCapabilities.arCapabilities.lidarPresent)
            capabilityRow("Scene Reconstruction", deviceCapabilities.arCapabilities.sceneReconstructionSupported)
            capabilityRow("Environment Texturing", deviceCapabilities.arCapabilities.environmentTexturingSupported)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Sensor Capabilities Section
    private var sensorCapabilitiesSection: some View {
        VStack(alignment: .leading) {
            sectionHeader("Sensor Capabilities")
            
            capabilityRow("Accelerometer", deviceCapabilities.sensorCapabilities.accelerometer)
            capabilityRow("Gyroscope", deviceCapabilities.sensorCapabilities.gyroscope)
            capabilityRow("Magnetometer", deviceCapabilities.sensorCapabilities.magnetometer)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Permission Status Section
    private var permissionStatusSection: some View {
        VStack(alignment: .leading) {
            sectionHeader("Permissions")
            
            permissionRow("Camera", deviceCapabilities.permissionStatuses.camera)
            permissionRow("Photo Library", deviceCapabilities.permissionStatuses.photoLibrary)
            permissionRow("Location", deviceCapabilities.permissionStatuses.location)
            permissionRow("Microphone", deviceCapabilities.permissionStatuses.microphone)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                // Check permissions again
                LogManager.shared.userAction("RefreshedPermissions")
                deviceCapabilities.checkPermissionStatuses {
                    // This will be called when all permission checks are complete
                }
            }) {
                Text("Refresh Permissions")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Button(action: {
                // Log a test event
                LogManager.shared.userAction("TestedDeviceCapabilities", details: [
                    "timestamp": Date().timeIntervalSince1970,
                    "performanceTest": true
                ])
                
                // Measure performance of a sample operation
                LogManager.shared.measure("Sample Performance Test") {
                    // Simulate some work
                    let iterations = 100_000
                    var result = 0
                    for i in 0..<iterations {
                        result += i
                    }
                    print("Result: \(result)")
                }
            }) {
                Text("Run Test Log")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }
    
    // Helper Views
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.bottom, 8)
    }
    
    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
    
    private func capabilityRow(_ title: String, _ isSupported: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            if isSupported {
                Text("Supported")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            } else {
                Text("Not Supported")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func permissionRow(_ title: String, _ status: DeviceCapabilityManager.PermissionStatuses.PermissionStatus) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            
            switch status {
            case .authorized:
                Text("Granted")
                    .foregroundColor(.green)
                    .fontWeight(.medium)
            case .denied:
                Text("Denied")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            case .notDetermined:
                Text("Not Determined")
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            case .restricted:
                Text("Restricted")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            case .limited:
                Text("Limited")
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            case .unknown:
                Text("Unknown")
                    .foregroundColor(.gray)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CapabilityCheckView()
        .environmentObject(ARSessionManager())
}
