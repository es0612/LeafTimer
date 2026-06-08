import XCTest
import ViewInspector
import SwiftUI
@testable import LeafTimer

final class OnboardingViewSpec: XCTestCase {
    func testSkipButtonInvokesOnFinish() throws {
        var finished = false
        let sut = OnboardingView(onFinish: { finished = true })

        // 最初に見つかる Button は TabView の上にある skip ボタン
        let button = try sut.body.inspect().find(ViewType.Button.self)
        try button.tap()

        XCTAssertTrue(finished)
    }
}
