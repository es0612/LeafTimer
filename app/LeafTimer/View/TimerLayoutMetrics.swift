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

    /// Issue #188: 葉を START ボタンに重ねる深さの、ボタン直径に対する比率 (直径 150pt で 20pt)。
    static let leafOverlapRatio: CGFloat = 20.0 / 150.0

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
        case .mid: 140 * scale
        case .big: 290 * scale
        }
    }

    /// Issue #188: 葉の frame の上端をボタンの上端に合わせたあと、y 方向に動かす量。
    /// 葉の下端がボタン上端から `buttonDiameter * leafOverlapRatio` だけ下に来る。
    /// 直径は Dynamic Type で変わる (CircleButton.resolvedDiameter) ので、重なりも追従する。
    func leafOffsetY(for pattern: LeafPattern, buttonDiameter: CGFloat) -> CGFloat {
        buttonDiameter * Self.leafOverlapRatio - leafSize(for: pattern)
    }

    func leafLeadingPadding(for pattern: LeafPattern) -> CGFloat {
        switch pattern {
        case .mid: 8 * scale
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
