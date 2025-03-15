//
//  ARMessageManager.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/15/25.
//

//
//  MessageManager.swift
//  TintSpace
//
//

import Foundation
import SwiftUI
import Combine

class ARMessageManager: ObservableObject {
    @Published private(set) var currentMessage: ARMessage?
    private var messageQueue: [ARMessage] = []
    private var timer: Timer?

    struct ARMessage: Identifiable {
        let id = UUID()
        let text: String
        let duration: TimeInterval
        let position: MessagePosition
        let icon: String?
        let animated: Bool?
        let isImmediate: Bool
        let symbolRenderingMode: SymbolRenderingMode?
        let symbolEffect: SymbolEffectOptions?
        
        init(text: String, duration: TimeInterval, position: MessagePosition, icon: String? = nil, isImmediate: Bool = false, animated: Bool = false, symbolRenderingMode: SymbolRenderingMode? = nil, symbolEffect: SymbolEffectOptions? = nil) {
            self.text = text
            self.duration = duration
            self.position = position
            self.icon = icon
            self.isImmediate = isImmediate
            self.animated = animated
            self.symbolRenderingMode = symbolRenderingMode
            self.symbolEffect = symbolEffect
        }
    }

    enum MessagePosition {
        case top, center, bottom
    }

    // Updated enum to work with correct SymbolEffect types
    enum SymbolEffectOptions {
        case bounce
        case scale
        case pulse
        case none
        
        @ViewBuilder
        func apply(to content: some View, value: Bool) -> some View {
            switch self {
            case .bounce:
                if #available(iOS 18.0, *) {
                    content.symbolEffect(.bounce, options: .repeat(.continuous), value: value)
                } else {
                    content
                        .offset(y: value ? -5 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: value)
                }
            case .scale:
                content.scaleEffect(value ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: value)
            case .pulse:
                if #available(iOS 18.0, *) {
                    content.symbolEffect(.pulse, options: .repeat(.periodic), value: value)
                } else {
                    content
                        .opacity(value ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: value)
                }
            case .none:
                content
            }
        }
    }

    func showMessage(
        _ text: String,
        duration: TimeInterval = 2.0,
        position: MessagePosition = .bottom,
        icon: String? = nil,
        isImmediate: Bool = false,
        animated: Bool = false,
        symbolRenderingMode: SymbolRenderingMode? = nil,
        symbolEffect: SymbolEffectOptions? = nil
    ) {
        let message = ARMessage(
            text: text,
            duration: duration,
            position: position,
            icon: icon,
            isImmediate: isImmediate,
            animated: animated,
            symbolRenderingMode: symbolRenderingMode,
            symbolEffect: symbolEffect
        )
        
        if isImmediate {
            hideMessage()
        }
        
        messageQueue.append(message)

        if currentMessage == nil {
            displayNextMessage()
        }
    }

    private func displayNextMessage() {
        guard !messageQueue.isEmpty else {
            currentMessage = nil
            return
        }
        
        currentMessage = messageQueue.removeFirst()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentMessage!.duration, repeats: false) { [weak self] _ in
            self?.hideMessage()
        }
    }

    func hideMessage() {
        timer?.invalidate()
        currentMessage = nil
        
        if !messageQueue.isEmpty {
            displayNextMessage()
        }
    }
    
    func removeAll() {
        currentMessage = nil
        messageQueue.removeAll()
        timer?.invalidate()
        timer = nil
    }
}
