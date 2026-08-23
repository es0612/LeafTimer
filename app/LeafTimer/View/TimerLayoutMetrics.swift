import CoreGraphics

/// Issue #64: トップ画面の葉レイアウトを画面サイズ比率で計算する純粋ロジック。
/// View から分離し、SE / iPad の各サイズをユニットテスト可能にする。
struct TimerLayoutMetrics: Equatable {
    /// iPhone 17 で GeometryReader が返す content 高さの近似。ここで scale = 1.0 になり
    /// 現行の固定値 (90/200/350pt) が維持される。
    static let referenceContentHeight: CGFloat = 760
    /// iPhone 17 の画面幅。Issue #114: iPad Split View の細長ウィンドウ (幅 320pt ×
    /// 高さ ~1000pt) で高さ比だけだと big 葉が横にはみ出すため、幅比との min を取る。
    static let referenceContentWidth: CGFloat = 390
    /// 下限は SE 系の視認性、上限は iPad でのバルーン化防止。
    static let scaleRange: ClosedRange<CGFloat> = 0.55...1.35

    let scale: CGFloat

    init(contentSize: CGSize) {
        let rawScale = min(
            contentSize.height / Self.referenceContentHeight,
            contentSize.width / Self.referenceContentWidth
        )
        scale = min(max(rawScale, Self.scaleRange.lowerBound), Self.scaleRange.upperBound)
    }

    func leafSize(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 90 * scale
        case .mid: 200 * scale
        case .big: 350 * scale
        }
    }

    func leafBottomPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 105 * scale
        case .mid: 150 * scale
        case .big: 300 * scale
        }
    }

    func leafLeadingPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .mid: 11 * scale
        default: 0
        }
    }

    func leafTrailingPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .small: 22 * scale
        default: 0
        }
    }
}
