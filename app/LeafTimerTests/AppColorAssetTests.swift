import XCTest
@testable import LeafTimer

/// Issue #63: 直書きしていた色を App/Assets.xcassets の named color に移した際、
/// 「名前が解決できる (未登録カタログに置いて既定色へフォールバックしない)」ことと
/// 「値が旧来の直書きと同じ (見た目不変)」ことを固定する。
final class AppColorAssetTests: XCTestCase {

    private struct Expected {
        let color: AppColor
        let space: CGColorSpace
        let light: [CGFloat]
        let dark: [CGFloat]
    }

    private static let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
    private static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    /// 旧 getColor1()〜4() の `Color(.init(red:…))` は `CGColor(red:green:blue:alpha:)` に解決され、
    /// Generic RGB で描かれていた (2026-10-18 ピクセル実測: WorkRing4 0.35/0.68/0.29 → sRGB 105,184,92)。
    /// 期待値は旧コードと同じ生成方法の色空間で比べる。
    private static let genericRGB = CGColor(red: 0, green: 0, blue: 0, alpha: 1).colorSpace!

    /// 旧来の直書き値 (2026-10-18 master 66c579f)。dark を持たない輪は dark = light。
    private static let expected: [Expected] = [
        // TimerViewModel+extensions.swift getBackgroundColor (Color(.displayP3, …))
        Expected(color: .workGradientTop, space: p3, light: [0.95, 0.98, 0.95], dark: [0.18, 0.22, 0.18]),
        Expected(color: .workGradientBottom, space: p3, light: [0.87, 0.91, 0.85], dark: [0.25, 0.30, 0.23]),
        Expected(color: .breakGradientTop, space: p3, light: [0.94, 0.96, 0.98], dark: [0.18, 0.20, 0.24]),
        Expected(color: .breakGradientBottom, space: p3, light: [0.77, 0.80, 0.88], dark: [0.25, 0.30, 0.36]),
        // getColor1()〜getColor4() (Color(CGColor(red:…)) = Generic RGB)
        Expected(color: .workRing1, space: genericRGB, light: [0.35, 0.47, 0.35], dark: [0.35, 0.47, 0.35]),
        Expected(color: .workRing2, space: genericRGB, light: [0.57, 0.73, 0.52], dark: [0.57, 0.73, 0.52]),
        Expected(color: .workRing3, space: genericRGB, light: [0.49, 0.71, 0.41], dark: [0.49, 0.71, 0.41]),
        Expected(color: .workRing4, space: genericRGB, light: [0.35, 0.68, 0.29], dark: [0.35, 0.68, 0.29]),
        Expected(color: .breakRing1, space: genericRGB, light: [0.35, 0.38, 0.46], dark: [0.35, 0.38, 0.46]),
        Expected(color: .breakRing2, space: genericRGB, light: [0.52, 0.66, 0.73], dark: [0.52, 0.66, 0.73]),
        Expected(color: .breakRing3, space: genericRGB, light: [0.41, 0.57, 0.71], dark: [0.41, 0.57, 0.71]),
        Expected(color: .breakRing4, space: genericRGB, light: [0.29, 0.45, 0.67], dark: [0.29, 0.45, 0.67]),
        // HistoryView.barColor(for:) (Color(red:…))
        Expected(color: .historyBar, space: srgb, light: [0.42, 0.56, 0.42], dark: [0.62, 0.76, 0.62]),
    ]

    func testEveryAppColorResolvesInAppBundle() {
        XCTAssertEqual(AppColor.allCases.count, 13)
        for color in AppColor.allCases {
            XCTAssertNotNil(UIColor(named: color.rawValue, in: .main, compatibleWith: nil), color.rawValue)
        }
    }

    func testResolvedValuesMatchFormerLiterals() throws {
        XCTAssertEqual(Set(Self.expected.map(\.color)), Set(AppColor.allCases))
        for item in Self.expected {
            let named = try XCTUnwrap(UIColor(named: item.color.rawValue, in: .main, compatibleWith: nil), item.color.rawValue)
            for (style, values) in [(UIUserInterfaceStyle.light, item.light), (.dark, item.dark)] {
                let resolved = named.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
                let components = try XCTUnwrap(
                    resolved.cgColor.converted(to: item.space, intent: .defaultIntent, options: nil)?.components
                )
                for index in 0..<3 {
                    XCTAssertEqual(
                        components[index], values[index], accuracy: 0.002,
                        "\(item.color.rawValue) \(style == .dark ? "dark" : "light") component \(index)"
                    )
                }
            }
        }
    }
}
