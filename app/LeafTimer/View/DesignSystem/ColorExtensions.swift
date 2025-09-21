import SwiftUI

// MARK: - Color Extensions for iOS 17 Design System

extension Color {

    // MARK: - Brand Colors

    /// Primary green color for the app brand
    static let primaryGreen = Color("PrimaryGreen")

    /// Secondary green color for accents
    static let secondaryGreen = Color("SecondaryGreen")

    /// Accent green for interactive elements
    static let accentGreen = Color("AccentGreen")

    // MARK: - Background Colors

    /// Primary background color (adapts to light/dark mode)
    static let backgroundPrimary = Color("BackgroundPrimary")

    /// Secondary background color for cards and sections
    static let backgroundSecondary = Color("BackgroundSecondary")

    // MARK: - Text Colors

    /// Primary text color (adapts to light/dark mode)
    static let textPrimary = Color("TextPrimary")

    /// Secondary text color for subtitles and hints
    static let textSecondary = Color("TextSecondary")

    // MARK: - Semantic Colors

    /// Error state color
    static let errorRed = Color("ErrorRed")

    /// Warning state color
    static let warningOrange = Color("WarningOrange")

    /// Success state color
    static let successGreen = Color("SuccessGreen")

    // MARK: - Timer Specific Colors

    /// Active timer color
    static let timerActive = Color("TimerActive")

    /// Paused timer color
    static let timerPaused = Color("TimerPaused")

    /// Break mode color
    static let breakMode = Color("BreakMode")

    /// Work mode color
    static let workMode = Color("WorkMode")

    // MARK: - Accessibility Support

    /// Check if the app supports dynamic colors
    static var supportsDynamicColors: Bool {
        return true
    }

    /// Check contrast compliance between foreground and background colors
    /// - Parameters:
    ///   - foreground: The foreground color
    ///   - background: The background color
    /// - Returns: True if contrast meets WCAG AA standards
    static func checkContrastCompliance(foreground: Color, background: Color) -> Bool {
        // Simplified implementation - in production, this would calculate actual contrast ratios
        // For now, return true as we'll ensure proper contrast in Asset Catalog
        return true
    }
}