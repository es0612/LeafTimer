import XCTest
import Foundation
@testable import LeafTimer

/// Data Persistence Testing for Task 1.2.3
/// Following TDD methodology to verify all data storage and retrieval functionality
class DataPersistenceTests: XCTestCase {

    var userDefaultsWrapper: LocalUserDefaultsWrapper!
    var mockWrapper: MockUserDefaultWrapper!
    var testUserDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Use a test-specific UserDefaults suite to avoid affecting real app data
        testUserDefaults = UserDefaults(suiteName: "DataPersistenceTests")
        userDefaultsWrapper = LocalUserDefaultsWrapper()
        mockWrapper = MockUserDefaultWrapper()

        // Clean up test data
        testUserDefaults?.removePersistentDomain(forName: "DataPersistenceTests")
    }

    override func tearDownWithError() throws {
        // Clean up test data
        testUserDefaults?.removePersistentDomain(forName: "DataPersistenceTests")
        testUserDefaults = nil
        userDefaultsWrapper = nil
        mockWrapper?.reset()
        mockWrapper = nil
        try super.tearDownWithError()
    }

    // MARK: - UserDefaults保存・読み込みテスト

    func testSaveAndLoadIntegerValues() {
        // RED Phase: This test should initially fail

        // Given: A key-value pair for integer data
        let testKey = "testIntKey"
        let testValue = 42

        // When: Saving integer value
        userDefaultsWrapper.saveData(key: testKey, value: testValue)

        // Then: Should be able to load the same value
        let loadedValue = userDefaultsWrapper.loadData(key: testKey)
        XCTAssertEqual(loadedValue, testValue, "Saved and loaded integer values should match")
    }

    func testSaveAndLoadBooleanValues() {
        // RED Phase: This test should initially fail

        // Given: A key-value pair for boolean data
        let testKey = "testBoolKey"
        let testValue = true

        // When: Saving boolean value
        userDefaultsWrapper.saveData(key: testKey, value: testValue)

        // Then: Should be able to load the same value
        let loadedValue = userDefaultsWrapper.loadData(key: testKey)
        XCTAssertEqual(loadedValue, testValue, "Saved and loaded boolean values should match")
    }

    func testDefaultValuesForMissingKeys() {
        // Given: A key that doesn't exist in UserDefaults
        let nonExistentKey = "nonExistentKey"

        // When: Loading data for non-existent key
        let intValue = userDefaultsWrapper.loadData(key: nonExistentKey) as Int
        let boolValue = userDefaultsWrapper.loadData(key: nonExistentKey) as Bool

        // Then: Should return default values
        XCTAssertEqual(intValue, 0, "Default integer value should be 0")
        XCTAssertEqual(boolValue, false, "Default boolean value should be false")
    }

    // MARK: - 設定値の永続化確認

    func testWorkingTimeSettingPersistence() {
        // Given: Working time setting
        let workingTimeKey = UserDefaultItem.workingTime.rawValue
        let selectedIndex = 4 // 25 minutes

        // When: Saving working time setting
        userDefaultsWrapper.saveData(key: workingTimeKey, value: selectedIndex)

        // Then: Should persist the setting
        let loadedIndex = userDefaultsWrapper.loadData(key: workingTimeKey)
        XCTAssertEqual(loadedIndex, selectedIndex, "Working time setting should persist")

        // And: Should correspond to correct time value
        let expectedTimeInSeconds = ItemValue.workingTimeList[selectedIndex]
        let actualTimeInSeconds = ItemValue.workingTimeList[loadedIndex]
        XCTAssertEqual(actualTimeInSeconds, expectedTimeInSeconds, "Time value should match selected option")
    }

    func testBreakTimeSettingPersistence() {
        // Given: Break time setting
        let breakTimeKey = UserDefaultItem.breakTime.rawValue
        let selectedIndex = 4 // 5 minutes

        // When: Saving break time setting
        userDefaultsWrapper.saveData(key: breakTimeKey, value: selectedIndex)

        // Then: Should persist the setting
        let loadedIndex = userDefaultsWrapper.loadData(key: breakTimeKey)
        XCTAssertEqual(loadedIndex, selectedIndex, "Break time setting should persist")

        // And: Should correspond to correct time value
        let expectedTimeInSeconds = ItemValue.breakTimeList[selectedIndex]
        let actualTimeInSeconds = ItemValue.breakTimeList[loadedIndex]
        XCTAssertEqual(actualTimeInSeconds, expectedTimeInSeconds, "Break time value should match selected option")
    }

    func testVibrationSettingPersistence() {
        // Given: Vibration setting
        let vibrationKey = UserDefaultItem.vibration.rawValue
        let enableVibration = true

        // When: Saving vibration setting
        userDefaultsWrapper.saveData(key: vibrationKey, value: enableVibration)

        // Then: Should persist the setting
        let loadedValue = userDefaultsWrapper.loadData(key: vibrationKey)
        XCTAssertEqual(loadedValue, enableVibration, "Vibration setting should persist")
    }

    func testSoundSettingsPersistence() {
        // Given: Working and break sound settings
        let workingSoundKey = UserDefaultItem.workingSound.rawValue
        let breakSoundKey = UserDefaultItem.breakSound.rawValue
        let workingSoundIndex = 1 // Rain sound
        let breakSoundIndex = 2 // River sound

        // When: Saving sound settings
        userDefaultsWrapper.saveData(key: workingSoundKey, value: workingSoundIndex)
        userDefaultsWrapper.saveData(key: breakSoundKey, value: breakSoundIndex)

        // Then: Should persist both settings
        let loadedWorkingSound = userDefaultsWrapper.loadData(key: workingSoundKey)
        let loadedBreakSound = userDefaultsWrapper.loadData(key: breakSoundKey)

        XCTAssertEqual(loadedWorkingSound, workingSoundIndex, "Working sound setting should persist")
        XCTAssertEqual(loadedBreakSound, breakSoundIndex, "Break sound setting should persist")

        // And: Should correspond to correct sound files
        let expectedWorkingSound = ItemValue.soundListFileName[workingSoundIndex]
        let expectedBreakSound = ItemValue.soundListFileName[breakSoundIndex]
        let actualWorkingSound = ItemValue.soundListFileName[loadedWorkingSound]
        let actualBreakSound = ItemValue.soundListFileName[loadedBreakSound]

        XCTAssertEqual(actualWorkingSound, expectedWorkingSound, "Working sound file should match")
        XCTAssertEqual(actualBreakSound, expectedBreakSound, "Break sound file should match")
    }

    // MARK: - 日別カウントデータの保存確認

    func testDailyCountDataPersistence() {
        // Given: Today's date and count data
        let todayKey = DateManager.getToday()
        let sessionCount = 5

        // When: Saving daily count
        userDefaultsWrapper.saveData(key: todayKey, value: sessionCount)

        // Then: Should persist the count
        let loadedCount = userDefaultsWrapper.loadData(key: todayKey)
        XCTAssertEqual(loadedCount, sessionCount, "Daily count should persist")
    }

    func testMultipleDaysDataPersistence() {
        // Given: Multiple days of data
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"

        let testDates = [
            "2025/09/10",
            "2025/09/11",
            "2025/09/12",
        ]
        let testCounts = [3, 5, 2]

        // When: Saving multiple days data
        for (date, count) in zip(testDates, testCounts) {
            userDefaultsWrapper.saveData(key: date, value: count)
        }

        // Then: All data should persist correctly
        for (date, expectedCount) in zip(testDates, testCounts) {
            let loadedCount = userDefaultsWrapper.loadData(key: date)
            XCTAssertEqual(loadedCount, expectedCount, "Count for \(date) should persist")
        }
    }

    func testDateKeyGeneration() {
        // Given: Current date
        let todayKey = DateManager.getToday()

        // Then: Should generate valid date string key
        XCTAssertFalse(todayKey.isEmpty, "Date key should not be empty")
        XCTAssertTrue(todayKey.contains("/"), "Date key should contain '/' separators")

        // And: Should be in expected format (yyyy/MM/dd)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let parsedDate = dateFormatter.date(from: todayKey)
        XCTAssertNotNil(parsedDate, "Date key should be in correct format")
    }

    // MARK: - アプリ再起動後のデータ復元テスト

    func testDataPersistenceAcrossAppRestarts() {
        // Simulate app restart by creating new wrapper instance

        // Given: Initial data saved
        let testData = [
            UserDefaultItem.workingTime.rawValue: 4,
            UserDefaultItem.breakTime.rawValue: 2,
            UserDefaultItem.vibration.rawValue: 1, // true as int
            "2025/09/11": 7,
        ]

        // When: Saving data with first wrapper instance
        for (key, value) in testData {
            if key == UserDefaultItem.vibration.rawValue {
                userDefaultsWrapper.saveData(key: key, value: value == 1)
            } else {
                userDefaultsWrapper.saveData(key: key, value: value)
            }
        }

        // Simulate app restart - create new wrapper instance
        let newWrapper = LocalUserDefaultsWrapper()

        // Then: Data should be available in new wrapper
        XCTAssertEqual(newWrapper.loadData(key: UserDefaultItem.workingTime.rawValue), 4)
        XCTAssertEqual(newWrapper.loadData(key: UserDefaultItem.breakTime.rawValue), 2)
        XCTAssertEqual(newWrapper.loadData(key: UserDefaultItem.vibration.rawValue), true)
        XCTAssertEqual(newWrapper.loadData(key: "2025/09/11"), 7)
    }

    func testSettingsConsistencyAfterRestart() {
        // Given: Complete settings configuration
        let settings = [
            (UserDefaultItem.workingTime.rawValue, 3),    // 20 minutes
            (UserDefaultItem.breakTime.rawValue, 4),     // 5 minutes
            (UserDefaultItem.workingSound.rawValue, 1),  // Rain sound
            (UserDefaultItem.breakSound.rawValue, 2),     // River sound
        ]

        let boolSettings = [
            (UserDefaultItem.vibration.rawValue, true)
        ]

        // When: Saving all settings
        for (key, value) in settings {
            userDefaultsWrapper.saveData(key: key, value: value)
        }
        for (key, value) in boolSettings {
            userDefaultsWrapper.saveData(key: key, value: value)
        }

        // Simulate restart
        let restoredWrapper = LocalUserDefaultsWrapper()

        // Then: All settings should be consistent
        for (key, expectedValue) in settings {
            let actualValue = restoredWrapper.loadData(key: key)
            XCTAssertEqual(actualValue, expectedValue, "Setting \(key) should persist across restart")
        }
        for (key, expectedValue) in boolSettings {
            let actualValue = restoredWrapper.loadData(key: key)
            XCTAssertEqual(actualValue, expectedValue, "Boolean setting \(key) should persist across restart")
        }
    }

    // MARK: - データ破損時の復旧テスト

    func testCorruptedDataRecovery() {
        // Given: Corrupted data scenario (invalid values)
        let workingTimeKey = UserDefaultItem.workingTime.rawValue
        let invalidIndex = 999 // Out of range index

        // When: Setting invalid data
        userDefaultsWrapper.saveData(key: workingTimeKey, value: invalidIndex)
        let loadedValue = userDefaultsWrapper.loadData(key: workingTimeKey)

        // Then: Should handle gracefully (return the stored value, let app handle validation)
        XCTAssertEqual(loadedValue, invalidIndex, "Should return stored value even if invalid")

        // Additional check: App should validate against ItemValue ranges
        let isValidIndex = loadedValue >= 0 && loadedValue < ItemValue.workingTimeList.count
        XCTAssertFalse(isValidIndex, "App should detect invalid indices")
    }

    func testMissingDataDefaultHandling() {
        // Given: Missing data scenario
        let missingKeys = [
            UserDefaultItem.workingTime.rawValue,
            UserDefaultItem.breakTime.rawValue,
            UserDefaultItem.vibration.rawValue,
            UserDefaultItem.workingSound.rawValue,
            UserDefaultItem.breakSound.rawValue,
        ]

        // When: Loading data for keys that don't exist
        // Then: Should return appropriate default values
        for key in missingKeys {
            if key == UserDefaultItem.vibration.rawValue {
                let defaultValue = userDefaultsWrapper.loadData(key: key) as Bool
                XCTAssertEqual(defaultValue, false, "Default vibration should be false")
            } else {
                let defaultValue = userDefaultsWrapper.loadData(key: key) as Int
                XCTAssertEqual(defaultValue, 0, "Default integer value should be 0")
            }
        }
    }

    func testDataIntegrityAfterMultipleOperations() {
        // Given: Multiple rapid save/load operations
        let testKey = UserDefaultItem.workingTime.rawValue
        let iterations = 100

        // When: Performing rapid operations
        for i in 0..<iterations {
            let value = i % ItemValue.workingTimeList.count // Keep within valid range
            userDefaultsWrapper.saveData(key: testKey, value: value)

            let loadedValue = userDefaultsWrapper.loadData(key: testKey)
            XCTAssertEqual(loadedValue, value, "Data integrity should be maintained during rapid operations")
        }

        // Then: Final value should be correct
        let finalExpectedValue = (iterations - 1) % ItemValue.workingTimeList.count
        let finalActualValue = userDefaultsWrapper.loadData(key: testKey)
        XCTAssertEqual(finalActualValue, finalExpectedValue, "Final value should be correct")
    }

    // MARK: - Edge Cases and Error Handling

    func testEmptyStringKeys() {
        // Given: Empty string key
        let emptyKey = ""
        let testValue = 42

        // When: Saving with empty key
        // Then: Should handle gracefully (UserDefaults will store it)
        XCTAssertNoThrow(userDefaultsWrapper.saveData(key: emptyKey, value: testValue))
        XCTAssertNoThrow(userDefaultsWrapper.loadData(key: emptyKey))
    }

    func testVeryLongKeys() {
        // Given: Very long key string
        let longKey = String(repeating: "a", count: 1000)
        let testValue = 123

        // When: Saving with long key
        // Then: Should handle gracefully
        XCTAssertNoThrow(userDefaultsWrapper.saveData(key: longKey, value: testValue))
        let loadedValue = userDefaultsWrapper.loadData(key: longKey)
        XCTAssertEqual(loadedValue, testValue, "Long keys should work correctly")
    }

    func testSpecialCharactersInKeys() {
        // Given: Keys with special characters
        let specialKeys = ["key with spaces", "key/with/slashes", "key.with.dots", "key-with-dashes"]
        let testValue = 456

        // When: Saving with special character keys
        // Then: Should handle all special characters
        for key in specialKeys {
            XCTAssertNoThrow(userDefaultsWrapper.saveData(key: key, value: testValue))
            let loadedValue = userDefaultsWrapper.loadData(key: key)
            XCTAssertEqual(loadedValue, testValue, "Key '\(key)' should work correctly")
        }
    }

    func testConcurrentDataAccess() {
        // Given: Concurrent access scenario
        let testKey = "concurrentTestKey"
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 2

        // When: Performing concurrent operations
        DispatchQueue.global().async {
            for i in 0..<50 {
                self.userDefaultsWrapper.saveData(key: testKey, value: i)
            }
            expectation.fulfill()
        }

        DispatchQueue.global().async {
            for _ in 0..<50 {
                _ = self.userDefaultsWrapper.loadData(key: testKey)
            }
            expectation.fulfill()
        }

        // Then: Should complete without crashes
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNoThrow(userDefaultsWrapper.loadData(key: testKey))
    }

    // MARK: - Mock Wrapper Testing

    func testMockWrapperFunctionality() {
        // Given: Mock wrapper for testing
        let testKey = "mockTestKey"
        let testValue = 789

        // When: Using mock wrapper
        mockWrapper.saveData(key: testKey, value: testValue)
        let loadedValue = mockWrapper.loadData(key: testKey)

        // Then: Mock should behave correctly
        XCTAssertEqual(loadedValue, testValue, "Mock wrapper should work correctly")
        XCTAssertEqual(mockWrapper.saveDataIntCallCount, 1, "Save call count should be tracked")
        XCTAssertEqual(mockWrapper.loadDataIntCallCount, 1, "Load call count should be tracked")
    }

    func testMockWrapperReset() {
        // Given: Mock wrapper with data
        mockWrapper.saveData(key: "testKey", value: 123)
        mockWrapper.saveData(key: "testBoolKey", value: true)

        // When: Resetting mock wrapper
        mockWrapper.reset()

        // Then: All data and counters should be cleared
        XCTAssertEqual(mockWrapper.loadData(key: "testKey"), 0)
        XCTAssertEqual(mockWrapper.loadData(key: "testBoolKey"), false)
        XCTAssertEqual(mockWrapper.saveDataIntCallCount, 0)
        XCTAssertEqual(mockWrapper.saveDataBoolCallCount, 0)
    }
}
