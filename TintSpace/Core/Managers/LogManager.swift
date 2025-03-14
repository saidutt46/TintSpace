//
//  LogManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

import Foundation
import OSLog

/// A sophisticated logging system that provides consistent, formatted logs
/// with emoji indicators, timestamps, and support for multiple output destinations.
final class LogManager {
    // MARK: - Singleton
    
    /// Shared instance for app-wide access
    static let shared = LogManager()
    
    // MARK: - Log Types
    
    /// Types of logs with associated emoji indicators
    enum LogType: String {
        case debug = "🔍" // Detailed information for debugging
        case info = "ℹ️" // General information
        case success = "✅" // Successful operations
        case warning = "⚠️" // Potential issues
        case error = "❌" // Errors that don't crash the app
        case fatal = "💣" // Critical errors
        case network = "🌐" // Network-related logs
        case ui = "🎨" // UI-related logs
        case ar = "🥽" // AR-related logs
        case performance = "⚡️" // Performance metrics
        case analytics = "📊" // Analytics events
        case userAction = "👆" // User interactions
        
        /// Returns the OSLog category for this log type
        var category: String {
            return self.rawValue
        }
        
        /// Returns the OS log type mapping for system integration
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info, .success, .ui, .network, .ar, .analytics, .userAction: return .info
            case .warning, .performance: return .default
            case .error: return .error
            case .fatal: return .fault
            }
        }
    }
    
    // MARK: - Properties
    
    /// Controls whether logs are shown in production
    private let showLogsInProduction: Bool
    
    /// Log level threshold - logs below this level won't be shown
    private let logLevel: LogLevel
    
    /// OS Log subsystem identifier for system integration
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.yourcompany.TintSpace"
    
    /// Mapping of log types to their OSLog instances
    private var loggers: [LogType: OSLog] = [:]
    
    /// File URL for log file if file logging is enabled
    private let logFileURL: URL?
    
    /// Queue for async logging to prevent blocking the main thread
    private let logQueue = DispatchQueue(label: "com.yourcompany.TintSpace.logging", qos: .utility)
    
    // MARK: - Log Levels
    
    /// Log level thresholds for filtering logs
    enum LogLevel: Int, Comparable {
        case verbose = 0
        case debug = 1
        case info = 2
        case warning = 3
        case error = 4
        case none = 5
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes the LogManager with the specified configuration
    ///
    /// - Parameters:
    ///   - logLevel: The minimum log level to display
    ///   - showLogsInProduction: Whether logs should be shown in production builds
    ///   - enableFileLogging: Whether logs should also be written to a file
    init(logLevel: LogLevel = .verbose,
         showLogsInProduction: Bool = false,
         enableFileLogging: Bool = false) {
        self.logLevel = logLevel
        self.showLogsInProduction = showLogsInProduction
        
        // Initialize loggers for each log type
        for logType in [LogType.debug, .info, .success, .warning, .error,
                        .fatal, .network, .ui, .ar, .performance, .analytics, .userAction] {
            loggers[logType] = OSLog(subsystem: subsystem, category: logType.category)
        }
        
        // Set up file logging if enabled
        if enableFileLogging {
            let fileManager = FileManager.default
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logDirectory = documentsDirectory.appendingPathComponent("Logs")
            
            // Create logs directory if it doesn't exist
            if !fileManager.fileExists(atPath: logDirectory.path) {
                try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            }
            
            // Create log file with current date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            logFileURL = logDirectory.appendingPathComponent("TintSpace-\(dateString).log")
        } else {
            logFileURL = nil
        }
        
        // Log initialization message
        info(message: "LogManager initialized with log level: \(logLevel)", category: "System")
    }
    
    // MARK: - Logging Methods
    
    /// Logs a debug message
    /// - Parameters:
    ///   - message: The message to log
    ///   - file: The file from which the log is called (auto-filled)
    ///   - function: The function from which the log is called (auto-filled)
    ///   - line: The line from which the log is called (auto-filled)
    ///   - category: Optional category for grouping logs
    ///   - object: Optional object to include in the log
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .debug, message: message, file: file, function: function, line: line, category: category, object: object, level: .debug)
    }
    
    /// Logs an informational message
    func info(message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .info, message: message, file: file, function: function, line: line, category: category, object: object, level: .info)
    }
    
    /// Logs a success message
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .success, message: message, file: file, function: function, line: line, category: category, object: object, level: .info)
    }
    
    /// Logs a warning message
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .warning, message: message, file: file, function: function, line: line, category: category, object: object, level: .warning)
    }
    
    /// Logs an error message
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil, error: Error? = nil) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Error: \(error.localizedDescription)"
        }
        log(type: .error, message: fullMessage, file: file, function: function, line: line, category: category, object: object, level: .error)
    }
    
    /// Logs a fatal error message
    func fatal(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil, error: Error? = nil) {
        var fullMessage = message
        if let error = error {
            fullMessage += " | Fatal Error: \(error.localizedDescription)"
        }
        log(type: .fatal, message: fullMessage, file: file, function: function, line: line, category: category, object: object, level: .error)
    }
    
    /// Logs a network-related message
    func network(_ message: String, file: String = #file, function: String = #function, line: Int = #line, request: URLRequest? = nil, response: URLResponse? = nil, data: Data? = nil, error: Error? = nil) {
        var details = [String]()
        if let request = request {
            details.append("URL: \(request.url?.absoluteString ?? "nil")")
            details.append("Method: \(request.httpMethod ?? "nil")")
            details.append("Headers: \(request.allHTTPHeaderFields ?? [:])")
        }
        if let response = response as? HTTPURLResponse {
            details.append("Status: \(response.statusCode)")
        }
        if let data = data, let jsonString = String(data: data, encoding: .utf8) {
            // Truncate long responses
            let truncated = jsonString.count > 500 ? "\(jsonString.prefix(500))..." : jsonString
            details.append("Response: \(truncated)")
        }
        if let error = error {
            details.append("Error: \(error.localizedDescription)")
        }
        
        let detailsString = details.isEmpty ? "" : " | \(details.joined(separator: " | "))"
        log(type: .network, message: "\(message)\(detailsString)", file: file, function: function, line: line, category: "Network", object: nil, level: .info)
    }
    
    /// Logs an AR-related message
    func ar(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .ar, message: message, file: file, function: function, line: line, category: category ?? "AR", object: object, level: .info)
    }
    
    /// Logs a UI-related message
    func ui(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
        log(type: .ui, message: message, file: file, function: function, line: line, category: category ?? "UI", object: object, level: .info)
    }
    
    /// Logs a performance metric
    func performance(_ message: String, file: String = #file, function: String = #function, line: Int = #line, duration: TimeInterval? = nil, memory: Int64? = nil) {
        var fullMessage = message
        if let duration = duration {
            fullMessage += " | Duration: \(String(format: "%.4f", duration))s"
        }
        if let memory = memory {
            fullMessage += " | Memory: \(ByteCountFormatter.string(fromByteCount: memory, countStyle: .file))"
        }
        log(type: .performance, message: fullMessage, file: file, function: function, line: line, category: "Performance", object: nil, level: .warning)
    }
    
    /// Logs an analytics event
    func analytics(_ eventName: String, parameters: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var message = "Event: \(eventName)"
        if let parameters = parameters {
            message += " | Parameters: \(parameters)"
        }
        log(type: .analytics, message: message, file: file, function: function, line: line, category: "Analytics", object: nil, level: .info)
    }
    
    /// Logs a user action
    func userAction(_ action: String, file: String = #file, function: String = #function, line: Int = #line, details: [String: Any]? = nil) {
        var message = "Action: \(action)"
        if let details = details {
            message += " | Details: \(details)"
        }
        log(type: .userAction, message: message, file: file, function: function, line: line, category: "UserAction", object: nil, level: .info)
    }
    
    // MARK: - Core Logging Implementation
    
    /// The core logging method that all other logging methods call
    ///
    /// - Parameters:
    ///   - type: The type of log
    ///   - message: The message to log
    ///   - file: The file from which the log is called
    ///   - function: The function from which the log is called
    ///   - line: The line from which the log is called
    ///   - category: Optional category for grouping logs
    ///   - object: Optional object to include in the log
    ///   - level: The log level
    private func log(type: LogType, message: String, file: String, function: String, line: Int, category: String?, object: Any?, level: LogLevel) {
        // Skip if below log level threshold
        guard level >= self.logLevel else { return }
        
        // Skip in production unless configured to show logs
        #if !DEBUG
        guard showLogsInProduction else { return }
        #endif
        
        // Format the log message
        let timestamp = Self.formattedDate()
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let categoryString = category != nil ? "[\(category!)] " : ""
        
        // Format object if present
        var objectString = ""
        if let object = object {
            if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
               let prettyJSON = String(data: data, encoding: .utf8) {
                objectString = "\nObject: \(prettyJSON)"
            } else {
                objectString = "\nObject: \(String(describing: object))"
            }
        }
        
        let fullMessage = "\(type.rawValue) \(timestamp) \(categoryString)\(message) (\(filename):\(line))\(objectString)"
        
        // Log to the console asynchronously
        logQueue.async {
            // Log to the system
            os_log("%{public}@", log: self.loggers[type]!, type: type.osLogType, fullMessage)
            
            // Log to file if enabled
            if let logFileURL = self.logFileURL {
                let fileMessage = "\(timestamp) [\(type)] \(categoryString)\(message) (\(filename):\(line))\(objectString)\n"
                if let data = fileMessage.data(using: .utf8) {
                    if FileManager.default.fileExists(atPath: logFileURL.path) {
                        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                            fileHandle.seekToEndOfFile()
                            fileHandle.write(data)
                            fileHandle.closeFile()
                        }
                    } else {
                        try? data.write(to: logFileURL, options: .atomicWrite)
                    }
                }
            }
        }
    }
    
    // MARK: - Utilities
    
    /// Returns a formatted date string for the log timestamp
    private static func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    /// Measures the execution time of a block of code
    ///
    /// - Parameters:
    ///   - name: A name for the performance measurement
    ///   - block: The block of code to measure
    /// - Returns: The result of the block
    func measure<T>(_ name: String, file: String = #file, function: String = #function, line: Int = #line, block: () throws -> T) rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let end = CFAbsoluteTimeGetCurrent()
        let duration = end - start
        performance("\(name) completed", file: file, function: function, line: line, duration: duration)
        return result
    }
    
    /// Measures the execution time of an async block of code
    ///
    /// - Parameters:
    ///   - name: A name for the performance measurement
    ///   - block: The async block of code to measure
    /// - Returns: The result of the block
    func measureAsync<T>(_ name: String, file: String = #file, function: String = #function, line: Int = #line, block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let end = CFAbsoluteTimeGetCurrent()
        let duration = end - start
        performance("\(name) completed", file: file, function: function, line: line, duration: duration)
        return result
    }
}

// MARK: - Global Logging Functions

/// Global function for quick debug logging
func log(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil, object: Any? = nil) {
    LogManager.shared.debug(message, file: file, function: function, line: line, category: category, object: object)
}

/// Global function for quick info logging
func logInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line, category: String? = nil) {
    LogManager.shared.info(message: message, file: file, function: function, line: line, category: category)
}

/// Global function for quick error logging
func logError(_ message: String, file: String = #file, function: String = #function, line: Int = #line, error: Error? = nil) {
    LogManager.shared.error(message, file: file, function: function, line: line, error: error)
}
