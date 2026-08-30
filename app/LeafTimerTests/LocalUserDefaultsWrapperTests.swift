// app/LeafTimerTests/LocalUserDefaultsWrapperTests.swift
import XCTest
@testable import LeafTimer

/// Issue #77: 設定・統計の保存先そのものの実体テスト。Mock でなく suite 指定の UserDefaults に
/// 実際に書いて読む round-trip を検証する (パターンは SessionStatsMigrationTests を踏襲)。
final class LocalUserDefaultsWrapperTests: XCTestCase {

    private let suiteName = "LocalUserDefaultsWrapperTests"
    private var testDefaults: UserDefaults!
    private var wrapper: LocalUserDefaultsWrapper!

    override func setUp() {
        super.setUp()
        testDefaults = UserDefaults(suiteName: suiteName)
        testDefaults.removePersistentDomain(forName: suiteName)
        wrapper = LocalUserDefaultsWrapper(userDefaults: testDefaults)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        wrapper = nil
        super.tearDown()
    }

    func testIntRoundTrip() {
        wrapper.saveData(key: "LocalUserDefaultsWrapperTests.int", value: 3)
        XCTAssertEqual(wrapper.loadData(key: "LocalUserDefaultsWrapperTests.int") as Int, 3)
        // 実体の UserDefaults に書かれている (Mock でない) ことを直接確認
        XCTAssertEqual(testDefaults.integer(forKey: "LocalUserDefaultsWrapperTests.int"), 3)
    }

    func testIntOverwrite() {
        wrapper.saveData(key: "LocalUserDefaultsWrapperTests.int", value: 3)
        wrapper.saveData(key: "LocalUserDefaultsWrapperTests.int", value: 7)
        XCTAssertEqual(wrapper.loadData(key: "LocalUserDefaultsWrapperTests.int") as Int, 7)
    }

    func testIntMissingKeyReturnsZero() {
        XCTAssertEqual(wrapper.loadData(key: "never.saved") as Int, 0)
    }

    func testBoolRoundTrip() {
        wrapper.saveData(key: "LocalUserDefaultsWrapperTests.bool", value: true)
        XCTAssertTrue(wrapper.loadData(key: "LocalUserDefaultsWrapperTests.bool") as Bool)
        XCTAssertTrue(testDefaults.bool(forKey: "LocalUserDefaultsWrapperTests.bool"))
    }

    func testBoolMissingKeyReturnsFalse() {
        XCTAssertFalse(wrapper.loadData(key: "never.saved") as Bool)
    }

    func testKeysDoNotCollide() {
        wrapper.saveData(key: "a", value: 1)
        wrapper.saveData(key: "b", value: 2)
        XCTAssertEqual(wrapper.loadData(key: "a") as Int, 1)
        XCTAssertEqual(wrapper.loadData(key: "b") as Int, 2)
    }

    func testDefaultInitUsesStandardDefaults() {
        // 引数なし init は .standard を使う (既存 5 箇所の呼び出しの契約)。
        // .standard を汚さないよう固有キーを使い、テスト後に消す。
        let key = "LocalUserDefaultsWrapperTests.standard.probe"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        LocalUserDefaultsWrapper().saveData(key: key, value: 42)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: key), 42)
    }
}
