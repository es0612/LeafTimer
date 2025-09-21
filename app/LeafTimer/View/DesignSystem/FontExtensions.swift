import SwiftUI

// MARK: - Font Extensions for iOS 17 Typography System

extension Font {

    // MARK: - Timer Display Fonts

    /// Large timer display font with ultra-light weight
    static let timerDisplay = Font.system(size: 72, weight: .ultraLight, design: .monospaced)

    /// Timer display size constant
    static let timerDisplaySize: CGFloat = 72

    /// Dynamic timer display font
    static func timerDisplayDynamic(_ sizeCategory: ContentSizeCategory) -> Font {
        let baseSize = timerDisplaySize
        // Use scaled font for dynamic type support
        let scaleFactor: CGFloat = {
            switch sizeCategory {
            case .extraSmall: return 0.8
            case .small: return 0.9
            case .medium: return 1.0
            case .large: return 1.1
            case .extraLarge: return 1.2
            case .extraExtraLarge: return 1.3
            case .extraExtraExtraLarge: return 1.4
            case .accessibilityMedium: return 1.5
            case .accessibilityLarge: return 1.6
            case .accessibilityExtraLarge: return 1.8
            case .accessibilityExtraExtraLarge: return 2.0
            case .accessibilityExtraExtraExtraLarge: return 2.4
            @unknown default: return 1.0
            }
        }()
        return Font.system(size: baseSize * scaleFactor, weight: .ultraLight, design: .monospaced)
    }

    /// Check if timer display is monospaced
    static var timerDisplayIsMonospaced: Bool { true }

    // MARK: - Session Count Fonts

    /// Session count display font
    static let sessionCount = Font.system(size: 24, weight: .semibold)

    /// Session count size constant
    static let sessionCountSize: CGFloat = 24

    // MARK: - UI Element Fonts

    /// Setting label font
    static let settingLabel = Font.system(size: 17, weight: .medium)

    /// Setting label size constant
    static let settingLabelSize: CGFloat = 17

    /// Body text font with Dynamic Type support
    static let bodyText = Font.body

    /// Dynamic body text font
    static func bodyTextDynamic(_ sizeCategory: ContentSizeCategory) -> Font {
        return Font.system(.body, design: .default)
    }

    // MARK: - Standard Typography

    /// Headline font (already exists in SwiftUI, but we can customize)
    static let headline = Font.system(.headline, design: .default).weight(.semibold)

    /// Subheadline font
    static let subheadline = Font.system(.subheadline, design: .default)

    /// Caption font
    static let caption = Font.system(.caption, design: .default)

    /// Footnote font
    static let footnote = Font.system(.footnote, design: .default)

    // MARK: - Button Typography

    /// Primary button font
    static let buttonPrimary = Font.system(size: 17, weight: .semibold)

    /// Secondary button font
    static let buttonSecondary = Font.system(size: 15, weight: .medium)

    // MARK: - Dynamic Type Support

    /// Check if Dynamic Type is supported
    static var supportsDynamicType: Bool {
        return true
    }
}

// MARK: - Text Style Extensions

extension Text {

    /// Apply timer display style
    func timerDisplayStyle() -> some View {
        self
            .font(.timerDisplay)
            .monospacedDigit()
    }

    /// Apply session count style
    func sessionCountStyle() -> some View {
        self
            .font(.sessionCount)
    }

    /// Apply setting label style
    func settingLabelStyle() -> some View {
        self
            .font(.settingLabel)
    }

    /// Apply primary button style
    func primaryButtonStyle() -> some View {
        self
            .font(.buttonPrimary)
    }

    /// Apply secondary button style
    func secondaryButtonStyle() -> some View {
        self
            .font(.buttonSecondary)
    }
}

// MARK: - Font Modifiers

struct DynamicTypeModifier: ViewModifier {
    @Environment(\.sizeCategory) var sizeCategory

    func body(content: Content) -> some View {
        content
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}

extension View {
    /// Enable Dynamic Type with accessibility sizes
    func dynamicTypeEnabled() -> some View {
        self.modifier(DynamicTypeModifier())
    }
}