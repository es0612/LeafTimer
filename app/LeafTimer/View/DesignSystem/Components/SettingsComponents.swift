import SwiftUI

// MARK: - Setting Row

struct SettingRow: View {
    let title: String
    let value: String
    let icon: String?
    let action: () -> Void

    init(title: String, value: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.value = value
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.primaryGreen)
                        .frame(width: 28)
                }

                Text(title)
                    .font(.settingLabel)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(value)
                    .font(.body)
                    .foregroundColor(.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textSecondary.opacity(0.5))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.backgroundSecondary)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}