import SwiftUI

struct MicLevelIndicatorView: View {

    let level: CGFloat

    private let activationThreshold: CGFloat = 0.02

    var body: some View {
        ZStack {
            Image(systemName: "mic")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.6))

            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .opacity(fillOpacity)
        }
        .scaleEffect(pulseScale)
        // Animate on LEVEL changes, not derived scale
        .animation(.easeOut(duration: 0.1), value: level)
        .padding(8)
    }

    // MARK: - Derived values

    private var fillOpacity: CGFloat {
        guard level > activationThreshold else { return 0.0 }
        return min(level * 2.5, 1.0)
    }

    private var pulseScale: CGFloat {
        guard level > activationThreshold else { return 1.0 }
        return 1.0 + min(level * 0.8, 1.2)
    }
}
