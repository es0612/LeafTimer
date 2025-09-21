import XCTest
import SwiftUI
@testable import LeafTimer

final class ComponentsTests: XCTestCase {

    // MARK: - PrimaryButton Tests

    func testPrimaryButtonInitialization() {
        let button = PrimaryButton(title: "Start", action: {})
        XCTAssertNotNil(button)
    }

    func testPrimaryButtonWithSystemImage() {
        let button = PrimaryButton(title: "Play", systemImage: "play.fill", action: {})
        XCTAssertNotNil(button)
    }

    // MARK: - SecondaryButton Tests

    func testSecondaryButtonInitialization() {
        let button = SecondaryButton(title: "Cancel", action: {})
        XCTAssertNotNil(button)
    }

    // MARK: - TimerCard Tests

    func testTimerCardInitialization() {
        let card = TimerCard(title: "Work Session", time: "25:00", color: .primaryGreen)
        XCTAssertNotNil(card)
    }

    // MARK: - SettingRow Tests

    func testSettingRowInitialization() {
        let row = SettingRow(title: "Sound", value: "Rain", action: {})
        XCTAssertNotNil(row)
    }

    func testSettingRowWithIcon() {
        let row = SettingRow(title: "Volume", value: "80%", icon: "speaker.wave.2", action: {})
        XCTAssertNotNil(row)
    }

    // MARK: - StatCard Tests

    func testStatCardInitialization() {
        let card = StatCard(title: "Today's Sessions", value: "8", icon: "clock.fill")
        XCTAssertNotNil(card)
    }

    // MARK: - ProgressRing Tests

    func testProgressRingInitialization() {
        let ring = ProgressRing(progress: 0.75, lineWidth: 10)
        XCTAssertNotNil(ring)
    }

    func testProgressRingWithCustomColors() {
        let ring = ProgressRing(progress: 0.5, lineWidth: 8, foregroundColor: .primaryGreen, backgroundColor: .gray)
        XCTAssertNotNil(ring)
    }

    // MARK: - IconBadge Tests

    func testIconBadgeInitialization() {
        let badge = IconBadge(systemName: "star.fill", color: .accentGreen)
        XCTAssertNotNil(badge)
    }

    // MARK: - AnimatedButton Tests

    func testAnimatedButtonInitialization() {
        let button = AnimatedButton(title: "Start", isAnimating: false, action: {})
        XCTAssertNotNil(button)
    }

    // MARK: - Toast Tests

    func testToastInitialization() {
        let toast = Toast(message: "Timer started", type: .success)
        XCTAssertNotNil(toast)
    }

    func testToastTypes() {
        let successToast = Toast(message: "Success", type: .success)
        let errorToast = Toast(message: "Error", type: .error)
        let warningToast = Toast(message: "Warning", type: .warning)
        let infoToast = Toast(message: "Info", type: .info)

        XCTAssertNotNil(successToast)
        XCTAssertNotNil(errorToast)
        XCTAssertNotNil(warningToast)
        XCTAssertNotNil(infoToast)
    }
}