//
//  AppDelegate.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import UIKit
import ARKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize LogManager with appropriate settings
        // In debug builds, we want verbose logging; in release builds, only warnings and above
        #if DEBUG
        _ = LogManager.shared // Initialize with default settings (verbose)
        #else
        _ = LogManager(logLevel: .warning, showLogsInProduction: false)
        #endif
        
        // Log app launch
        LogManager.shared.info(message: "TintSpace app launched", category: "AppLifecycle")
        
        // Initialize DeviceCapabilityManager to check device capabilities
        let deviceCapabilities = DeviceCapabilityManager.shared
        
        // Log if device meets requirements
        if deviceCapabilities.deviceMeetsRequirements() {
            LogManager.shared.success("Device meets all requirements for TintSpace", category: "AppSetup")
        } else {
            let missingCapabilities = deviceCapabilities.getMissingCapabilities()
            LogManager.shared.warning("Device might not fully support TintSpace. Missing: \(missingCapabilities.joined(separator: ", "))", category: "AppSetup")
        }
        
        // Check permissions asynchronously
        deviceCapabilities.checkPermissionStatuses {
            LogManager.shared.info(message: "Permission check completed", category: "Permissions")
        }
        
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        LogManager.shared.info(message: "TintSpace app will terminate", category: "AppLifecycle")
    }
}
