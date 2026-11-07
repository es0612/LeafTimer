import UIKit
import XCTest
@testable import LeafTimer

// Issue #201: iOS / iPadOS 27.2 で UIScene 未対応のアプリは起動時に assert で落ちる。
// manifest の宣言と、scene の lifecycle から background task が動くことを確かめる。
final class SceneLifecycleTests: XCTestCase {
    private var runner: SpyBackgroundTaskRunner!
    private var keeper: BackgroundTaskKeeper!

    override func setUp() {
        super.setUp()
        runner = SpyBackgroundTaskRunner()
        keeper = BackgroundTaskKeeper(runner: runner)
    }

    override func tearDown() {
        keeper = nil
        runner = nil
        super.tearDown()
    }

    func test_infoPlist_declaresSingleWindowSceneWithSceneDelegate() throws {
        let manifest = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any]
        )
        XCTAssertEqual(manifest["UIApplicationSupportsMultipleScenes"] as? Bool, false)

        let configurations = try XCTUnwrap(manifest["UISceneConfigurations"] as? [String: Any])
        let roles = try XCTUnwrap(configurations["UIWindowSceneSessionRoleApplication"] as? [[String: Any]])
        XCTAssertEqual(roles.count, 1)

        let className = try XCTUnwrap(roles.first?["UISceneDelegateClassName"] as? String)
        XCTAssertTrue(NSClassFromString(className) === SceneDelegate.self, "resolved: \(className)")
    }

    func test_keeper_begin_thenEnd_endsSameTaskAndResets() {
        keeper.begin()
        let started = runner.returnedIDs.first

        keeper.end()

        XCTAssertEqual(runner.beginCount, 1)
        XCTAssertEqual(runner.endedIDs, [started].compactMap { $0 })
        XCTAssertEqual(keeper.taskID, .invalid)
    }

    // #128: 初回 activation など、未登録のときは end しない
    func test_keeper_end_withoutBegin_doesNothing() {
        keeper.end()

        XCTAssertTrue(runner.endedIDs.isEmpty)
        XCTAssertEqual(keeper.taskID, .invalid)
    }

    // #70: 期限切れのハンドラでも task を終える
    func test_keeper_expirationHandler_endsTask() throws {
        keeper.begin()
        let handler = try XCTUnwrap(runner.lastExpirationHandler)

        handler()

        XCTAssertEqual(runner.endedIDs.count, 1)
        XCTAssertEqual(keeper.taskID, .invalid)
    }

    func test_sceneDelegate_resignActive_begins_and_becomeActive_ends() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first)
        let delegate = SceneDelegate()
        delegate.backgroundTaskKeeper = keeper

        delegate.sceneWillResignActive(scene)
        XCTAssertEqual(runner.beginCount, 1)

        delegate.sceneDidBecomeActive(scene)
        XCTAssertEqual(runner.endedIDs.count, 1)
    }
}

private final class SpyBackgroundTaskRunner: BackgroundTaskRunning {
    private(set) var beginCount = 0
    private(set) var returnedIDs: [UIBackgroundTaskIdentifier] = []
    private(set) var endedIDs: [UIBackgroundTaskIdentifier] = []
    private(set) var lastExpirationHandler: (() -> Void)?

    func beginBackgroundTask(expirationHandler: (() -> Void)?) -> UIBackgroundTaskIdentifier {
        beginCount += 1
        lastExpirationHandler = expirationHandler
        let id = UIBackgroundTaskIdentifier(rawValue: 100 + beginCount)
        returnedIDs.append(id)
        return id
    }

    func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {
        endedIDs.append(identifier)
    }
}
