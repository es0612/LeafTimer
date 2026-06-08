import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selection = 0

    private struct Page {
        let emoji: String
        let title: String
        let body: String
    }

    private var pages: [Page] {
        [
            Page(
                emoji: "🍃",
                title: NSLocalizedString("onboarding.welcome.title", comment: "Onboarding welcome title"),
                body: NSLocalizedString("onboarding.welcome.body", comment: "Onboarding welcome body")
            ),
            Page(
                emoji: "▶️",
                title: NSLocalizedString("onboarding.usage.title", comment: "Onboarding usage title"),
                body: NSLocalizedString("onboarding.usage.body", comment: "Onboarding usage body")
            ),
        ]
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    if selection < pages.count - 1 {
                        Button(NSLocalizedString("onboarding.skip", comment: "Skip onboarding")) {
                            onFinish()
                        }
                        .foregroundColor(.secondary)
                        .padding()
                    }
                }

                TabView(selection: $selection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Text(page.emoji)
                                .font(.system(size: 72))
                            Text(page.title)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            Text(page.body)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                if selection == pages.count - 1 {
                    Button(action: onFinish) {
                        Text(NSLocalizedString("onboarding.start_button", comment: "Get started button"))
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(onFinish: {})
    }
}
