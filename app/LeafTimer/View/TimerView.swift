import SwiftUI

struct TimerView: View {
    // MARK: - State

    @ObservedObject
    var timerViewModel: TimerViewModel
    @ObservedObject
    var settingViewModel: SettingViewModel
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showOnboarding = false

    /// タイマー数字は 78pt と大きく、本文と同率 (AX5 で約 3.1 倍) に拡大すると
    /// 画面幅に収まらない。largeTitle 基準 (約 1.76 倍) に緩めた上で上限を張る。
    @ScaledMetric(relativeTo: .largeTitle) private var timerFontSize: CGFloat = 78

    // MARK: - View

    var body: some View {
#if DEBUG
        if let screen = DebugInitialScreen.requested {
            debugScreen(screen)
        } else {
            timerContent
        }
#else
        timerContent
#endif
    }

#if DEBUG
    /// 検証用に単一画面を直接表示する。`simctl` には tap が無いため、
    /// 設定・履歴・プレビューは通常の導線 (歯車 → NavigationLink) では
    /// スクリーンショットを撮れない。
    ///
    /// EnhancedSettingView / HistoryView は通常 NavigationStack の内側で
    /// 描画されるので、ここでも NavigationStack で包む。裸で返すと
    /// ツールバーと navigationTitle が出ず、baseline が不正確になる。
    /// TimerPreviewSheet は自前で NavigationView を持つため包まない。
    @ViewBuilder
    private func debugScreen(_ screen: String) -> some View {
        switch screen {
        case "settings":
            NavigationStack {
                EnhancedSettingView(settingViewModel: settingViewModel)
            }
        case "history":
            NavigationStack {
                HistoryView(viewModel: timerViewModel.historyViewModel)
            }
        case "timePreview":
            TimerPreviewSheet(
                workingTime: ItemValue.workingTimeList[settingViewModel.workingTime],
                breakTime: ItemValue.breakTimeList[settingViewModel.breakTime]
            )
        default:
            timerContent
        }
    }
#endif

    /// Issue #113: 標準サイズは横並び、accessibility サイズは縦積み。
    private var statChipLayout: AnyLayout {
        StatChip.usesVerticalLayout(for: dynamicTypeSize)
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(spacing: 10))
    }

    private var timerContent: some View {
        NavigationStack {
            GeometryReader { geometry in
                let metrics = TimerLayoutMetrics(contentSize: geometry.size)
                ZStack {
                    timerViewModel.getBackgroundColor(colorScheme: colorScheme)
                        .ignoresSafeArea(.all)

                    leafLayer(metrics: metrics)

                    VStack {
                        Text(timerViewModel.getDisplayedTime())
                            .font(.system(size: min(timerFontSize, 110), weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundColor(.primary.opacity(0.9))
                            .shadow(color: .gray, radius: 1, x: 1, y: 2)
                            .padding(.bottom, 50)
                            .accessibilityLabel(NSLocalizedString("timer.a11y.remaining_time", comment: "Remaining time label"))
                            .accessibilityValue(timerViewModel.getAccessibilityTimeValue())
                            .accessibilityAddTraits(.updatesFrequently)

                        Button(action: didTapTimerButton) {
                            CircleButton(viewModel: timerViewModel)
                                .shadow(color: .gray, radius: 1, x: 1, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(timerViewModel.getAccessibilityLabel())

                        // Issue #113: accessibility サイズでは横並びが SE 幅に収まらないため縦積みへ
                        statChipLayout {
                            StatChip(
                                systemImage: "leaf.fill",
                                tint: .green,
                                text: String(
                                    format: NSLocalizedString("timer.stat.today", comment: "Today's pomodoro count"),
                                    timerViewModel.todaysCount
                                )
                            )
                            StatChip(
                                systemImage: "flame.fill",
                                tint: .orange,
                                text: String(
                                    format: NSLocalizedString("timer.stat.streak", comment: "Current streak"),
                                    timerViewModel.currentStreak
                                )
                            )
                        }
                        .padding()
                        .padding(.top, 20)
                    }
                    .navigationTitle(NSLocalizedString("timer.title", comment: "Timer navigation title"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: didTapResetButton) {
                                Image("reloadIcon").foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.reset", comment: "Reset timer button"))
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(
                                destination: HistoryView(
                                    viewModel: timerViewModel.historyViewModel
                                )
                            ) {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.history", comment: "History button"))
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: EnhancedSettingView(settingViewModel: settingViewModel)) {
                                Image("settingIcon").foregroundColor(.primary)
                            }
                            .accessibilityLabel(NSLocalizedString("timer.a11y.settings", comment: "Settings button"))
                        }
                    }
                    .onAppear {
                        timerViewModel.readData()
                        timerViewModel.openScreen()
                        if settingViewModel.shouldShowOnboarding() {
                            showOnboarding = true
                        }
                    }
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView {
                            settingViewModel.markOnboardingSeen()
                            showOnboarding = false
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    /// Issue #64: 葉の固定 frame/padding を TimerLayoutMetrics の比率値に置き換えた層。
    @ViewBuilder
    private func leafLayer(metrics: TimerLayoutMetrics) -> some View {
        let pattern: LeafPattern? = {
            if timerViewModel.breakState { return .big }
#if DEBUG
            if let forced = DebugLeafPattern.requested { return forced }
#endif
            return timerViewModel.getLeafPattern()
        }()

        if let pattern {
            let gifName = switch pattern {
            case .small: "leaf1"
            case .mid: "leaf2"
            case .big: "leaf3"
            }
            GIFView(gifName: gifName)
                .frame(
                    width: metrics.leafSize(for: pattern),
                    height: metrics.leafSize(for: pattern),
                    alignment: .center
                )
                .padding(.leading, metrics.leafLeadingPadding(for: pattern))
                .padding(.trailing, metrics.leafTrailingPadding(for: pattern))
                .padding(.bottom, metrics.leafBottomPadding(for: pattern))
        }
    }

    // MARK: - Private methods

    private func didTapTimerButton() {
        timerViewModel.onPressedTimerButton()
    }

    private func didTapResetButton() {
        timerViewModel.reset()
    }
}

#if DEBUG
/// 起動引数 `-InitialScreen=<name>` を読む。既存の `-UMPDebugGeographyEEA`
/// (Components/AdsConsentServices.swift:20) と同じ発想。
enum DebugInitialScreen {
    static let requested: String? = {
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-InitialScreen=") }?
            .replacingOccurrences(of: "-InitialScreen=", with: "")
    }()
}

/// Issue #64: 葉パターンは進捗依存で simctl から tap 操作できないため、
/// レイアウト検証用に起動引数で強制する。DebugInitialScreen と同じ発想。
enum DebugLeafPattern {
    static let requested: LeafPattern? = {
        let value = ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("-LeafPattern=") }?
            .replacingOccurrences(of: "-LeafPattern=", with: "")
        switch value {
        case "small": return .small
        case "mid": return .mid
        case "big": return .big
        default: return nil
        }
    }()
}
#endif

struct TimerView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(["iPhone 16"], id: \.self) { deviceName in
            TimerView(
                timerViewModel: TimerViewModel(
                    timerManager: DefaultTimerManager(),
                    audioManager: DefaultAudioManager(),
                    userDefaultWrapper: LocalUserDefaultsWrapper(),
                    sessionStatsRepository: LocalSessionStatsRepository()
                ),
                settingViewModel: SettingViewModel(userDefaultWrapper: LocalUserDefaultsWrapper())
            )
            .previewDevice(PreviewDevice(rawValue: deviceName))
            .previewDisplayName(deviceName)
        }
    }
}
