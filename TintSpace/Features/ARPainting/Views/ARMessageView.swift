//
//  ARMessageView.swift
//  TintSpace
//
//  Created by Sai Dutt Ganduri on 3/15/25.
//

//
//  ARMessageView.swift
//  TintSpace
//

// ARMessageView.swift

import SwiftUI

struct MessageView: View {
    let message: ARMessageManager.ARMessage
    @State private var isVisible = false
    @State private var isAnimating = false

    var body: some View {
        VStack {
            if message.position == .top || message.position == .center {
                Spacer()
            }
            
            HStack(spacing: 10) {
                if let icon = message.icon {
                    message.symbolEffect?.apply(to:
                        Image(systemName: icon)
                            .foregroundColor(.white)
                            .font(.system(size: 24))
                            .symbolRenderingMode(message.symbolRenderingMode ?? .monochrome),
                        value: isAnimating
                    )
                }
                
                Text(message.text)
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .semibold))
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(GlassyBlurView(style: .systemUltraThinMaterialDark))
            .cornerRadius(20)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0), value: isVisible)
            .onAppear {
                withAnimation {
                    isVisible = true
                }
                isAnimating = message.animated ?? false
            }
            .onDisappear {
                withAnimation {
                    isVisible = false
                }
            }

            if message.position == .bottom || message.position == .center {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct GlassyBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: style)
        let blurView = UIVisualEffectView(effect: blurEffect)

        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect)
        let vibrancyView = UIVisualEffectView(effect: vibrancyEffect)
        vibrancyView.frame = blurView.bounds
        vibrancyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(vibrancyView)

        return blurView
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
