import SwiftUI

// MARK: - Toast Type

enum ToastType {
    case success
    case error
    case warning
    case info

    var color: Color {
        switch self {
        case .success:
            return .successGreen
        case .error:
            return .errorRed
        case .warning:
            return .warningOrange
        case .info:
            return .primaryGreen
        }
    }

    var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - Toast View

struct Toast: View {
    let message: String
    let type: ToastType
    @State private var isShowing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(type.color)

            Text(message)
                .font(.body)
                .foregroundColor(.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let toast: Toast

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                VStack {
                    toast
                        .padding(.horizontal, 16)
                        .padding(.top, 50)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            isShowing = false
                        }
                    }
                }
            }
        }
    }
}

extension View {
    func toast(_ toast: Toast, isShowing: Binding<Bool>) -> some View {
        self.modifier(ToastModifier(isShowing: isShowing, toast: toast))
    }
}