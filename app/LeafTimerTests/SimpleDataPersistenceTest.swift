import XCTest
@testable import LeafTimer

/// Simple Data Persistence Test for Task 1.2.3 using XCTest
class SimpleDataPersistenceTest: XCTestCase {
    
    func testBasicUserDefaultsWrapper() {
        let wrapper = LocalUserDefaultsWrapper()
        wrapper.saveData(key: "testKey", value: 42)
        let result = wrapper.loadData(key: "testKey")
        XCTAssertEqual(result, 42)
    }
}