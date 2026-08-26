import Foundation
import os

/// Issue #70: 本番コードに散在していた `print()` の置き換え先。
/// `os.Logger` は Console.app / `xcrun simctl spawn <UDID> log stream` から
/// subsystem + category で絞り込めるため、リリースビルドでも診断できる。
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "jp.ema.LeafTimer"

    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let notification = Logger(subsystem: subsystem, category: "notification")
    static let gif = Logger(subsystem: subsystem, category: "gif")
}
