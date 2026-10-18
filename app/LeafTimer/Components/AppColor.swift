import SwiftUI

/// Issue #63: アプリ固有色の一覧。rawValue は App/Assets.xcassets の colorset 名。
/// light/dark の値は colorset 側に持たせ、コードには色の数値を書かない。
enum AppColor: String, CaseIterable {
    case workGradientTop = "WorkGradientTop"
    case workGradientBottom = "WorkGradientBottom"
    case breakGradientTop = "BreakGradientTop"
    case breakGradientBottom = "BreakGradientBottom"
    case workRing1 = "WorkRing1"
    case workRing2 = "WorkRing2"
    case workRing3 = "WorkRing3"
    case workRing4 = "WorkRing4"
    case breakRing1 = "BreakRing1"
    case breakRing2 = "BreakRing2"
    case breakRing3 = "BreakRing3"
    case breakRing4 = "BreakRing4"
    case historyBar = "HistoryBar"

    var color: Color {
        Color(rawValue)
    }
}
