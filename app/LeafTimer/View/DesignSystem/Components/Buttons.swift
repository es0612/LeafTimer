import SwiftUI

// MARK: - Primary Button

struct PrimaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    @State private var isPressed = false

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.buttonPrimary)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.primaryGreen)
            .cornerRadius(12)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.buttonSecondary)
                .foregroundColor(.primaryGreen)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primaryGreen, lineWidth: 1.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Animated Button

struct AnimatedButton: View {
    let title: String
    let isAnimating: Bool
    let action: () -> Void
    @State private var rotation = 0.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isAnimating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(title)
                    .font(.buttonPrimary)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.primaryGreen, Color.secondaryGreen]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color.primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isAnimating)
        .buttonStyle(PlainButtonStyle())
    }
}