import SwiftUI

struct AboutSettingsSection: View {
    @ObservedObject var viewModel: SettingViewModel

    var body: some View {
        Section {
            Button {
                viewModel.openAppStoreReviewPage()
            } label: {
                HStack {
                    Label(
                        NSLocalizedString("settings.review_app", comment: "Review this app"),
                        systemImage: "star.fill"
                    )
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        } header: {
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(.yellow)
                Text(NSLocalizedString("settings.about_section", comment: "About section header"))
            }
            .font(.system(size: 13, weight: .semibold))
            .textCase(.uppercase)
        } footer: {
            Text(NSLocalizedString(
                "settings.review_app_footer",
                comment: "Footer for review section"
            ))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }
}
