import SwiftUI

struct PulseAnimation: ViewModifier {
    @Binding var isAnimating: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isAnimating ? 1.03 : 1.0)
            .opacity(isAnimating ? 0.9 : 1.0)
            .animation(
                isAnimating ?
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true) :
                    .default,
                value: isAnimating
            )
    }
}

extension View {
    func pulseAnimation(_ isAnimating: Binding<Bool>) -> some View {
        modifier(PulseAnimation(isAnimating: isAnimating))
    }
}