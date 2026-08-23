import CoreGraphics

/// Issue #64: トップ画面の葉レイアウトを画面サイズ比率で計算する純粋ロジック。
/// View から分離し、SE / iPad の各サイズをユニットテスト可能にする。
struct TimerLayoutMetrics: Equatable {
    /// iPhone 17 で GeometryReader が返す content 高さの近似。ここで scale = 1.0 になり
    /// 現行の固定値 (90/200/350pt) が維持される。
    static let referenceContentHeight: CGFloat = 760
    /// 下限は SE 系の視認性、上限は iPad でのバルーン化防止。
    static let scaleRange: ClosedRange<CGFloat> = 0.55...1.35

    let scale: CGFloat

    init(contentSize: CGSize) {
        let rawScale = contentSize.height / Self.referenceContentHeight
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
