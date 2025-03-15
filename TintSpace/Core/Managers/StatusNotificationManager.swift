//
//  StatusNotificationManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/13/25.
//

//
//  StatusNotificationManager.swift
//  TintSpace
//
//  Created for TintSpace on 3/13/25.
//

import Foundation
import Combine
import SwiftUI

/// Priority levels for status notifications
enum MessagePriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: MessagePriority, rhs: MessagePriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// A status message with priority and lifecycle management
class StatusMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let priority: MessagePriority
    let dismissAfter: TimeInterval?
    let timestamp: Date
    let actionTitle: String?
    let action: (() -> Void)?
    
    /// Initialize a new status message
    /// - Parameters:
    ///   - message: The message text
    ///   - priority: The message priority
    ///   - dismissAfter: Optional auto-dismiss time
    ///   - actionTitle: Optional action button title
    ///   - action: Optional action to perform when tapped
    init(
        message: String,
        priority: MessagePriority,
        dismissAfter: TimeInterval? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.message = message
        self.priority = priority
        self.dismissAfter = dismissAfter
        self.timestamp = Date()
        self.actionTitle = actionTitle
        self.action = action
    }
    
    /// Messages are equal if they have the same ID
    static func == (lhs: StatusMessage, rhs: StatusMessage) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Manages status notifications throughout the app
final class StatusNotificationManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current active message
    @Published private(set) var currentMessage: StatusMessage?
    
    /// Queue of pending messages
    @Published private(set) var pendingMessages: [StatusMessage] = []
    
    /// Whether there are any pending or current messages
    var hasMessages: Bool {
        return currentMessage != nil || !pendingMessages.isEmpty
    }
    
    // MARK: - Private Properties
    
    /// Timer for auto-dismissing messages
    private var dismissTimer: Timer?
    
    /// Callback for message changes
    var onMessageChanged: ((StatusMessage?) -> Void)?
    
    // MARK: - Public Methods
    
    /// Shows a message with priority handling
    /// - Parameter message: The message to show
    func showMessage(_ message: StatusMessage) {
        // Check if we should replace current message based on priority
        if let currentMessage = currentMessage {
            if message.priority > currentMessage.priority {
                // New message has higher priority, replace current message
                pendingMessages.insert(currentMessage, at: 0)
                setCurrentMessage(message)
            } else {
                // Add to pending queue in priority order
                insertIntoPendingQueue(message)
            }
        } else {
            // No current message, show immediately
            setCurrentMessage(message)
        }
    }
    
    /// Shows an informational message
    /// - Parameters:
    ///   - message: The message text
    ///   - dismissAfter: Optional auto-dismiss time
    func showInfo(_ message: String, dismissAfter: TimeInterval? = 3.0) {
        showMessage(StatusMessage(
            message: message,
            priority: .low,
            dismissAfter: dismissAfter
        ))
    }
    
    /// Shows a success message
    /// - Parameters:
    ///   - message: The message text
    ///   - dismissAfter: Optional auto-dismiss time
    func showSuccess(_ message: String, dismissAfter: TimeInterval? = 3.0) {
        showMessage(StatusMessage(
            message: message,
            priority: .medium,
            dismissAfter: dismissAfter
        ))
    }
    
    /// Shows a warning message
    /// - Parameters:
    ///   - message: The message text
    ///   - dismissAfter: Optional auto-dismiss time
    func showWarning(_ message: String, dismissAfter: TimeInterval? = 5.0) {
        showMessage(StatusMessage(
            message: message,
            priority: .high,
            dismissAfter: dismissAfter
        ))
    }
    
    /// Shows an error message
    /// - Parameters:
    ///   - message: The message text
    ///   - dismissAfter: Optional auto-dismiss time
    ///   - actionTitle: Optional action button title
    ///   - action: Optional action to perform when tapped
    func showError(
        _ message: String,
        dismissAfter: TimeInterval? = 5.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        showMessage(StatusMessage(
            message: message,
            priority: .critical,
            dismissAfter: dismissAfter,
            actionTitle: actionTitle,
            action: action
        ))
    }
    
    /// Dismiss the current message
    func dismissCurrentMessage() {
        // Cancel the timer
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        // Clear current message
        currentMessage = nil
        
        // Notify listeners
        onMessageChanged?(nil)
        
        // Show next message if any
        showNextPendingMessageIfAvailable()
    }
    
    /// Clear all messages including pending ones
    func clearMessages() {
        // Cancel timer
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        // Clear messages
        currentMessage = nil
        pendingMessages.removeAll()
        
        // Notify listeners
        onMessageChanged?(nil)
    }
    
    // MARK: - Private Methods
    
    /// Set the current message and set up dismissal timer if needed
    /// - Parameter message: The message to set as current
    private func setCurrentMessage(_ message: StatusMessage) {
        // Cancel existing timer
        dismissTimer?.invalidate()
        
        // Set new current message
        currentMessage = message
        
        // Notify listeners
        onMessageChanged?(message)
        
        LogManager.shared.info(message: "Showing status message: \(message.message)", category: "StatusNotification")
        
        // Set up auto-dismiss timer if needed
        if let dismissAfter = message.dismissAfter {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: dismissAfter, repeats: false) { [weak self] _ in
                self?.dismissCurrentMessage()
            }
        }
    }
    
    /// Insert a message into the pending queue based on priority
    /// - Parameter message: The message to insert
    private func insertIntoPendingQueue(_ message: StatusMessage) {
        // Find where to insert based on priority (higher priority first)
        var insertIndex = pendingMessages.count
        
        for (index, pendingMessage) in pendingMessages.enumerated() {
            if message.priority > pendingMessage.priority {
                insertIndex = index
                break
            }
        }
        
        pendingMessages.insert(message, at: insertIndex)
    }
    
    /// Show the next pending message if available
    private func showNextPendingMessageIfAvailable() {
        guard let nextMessage = pendingMessages.first else { return }
        
        pendingMessages.removeFirst()
        setCurrentMessage(nextMessage)
    }
}
