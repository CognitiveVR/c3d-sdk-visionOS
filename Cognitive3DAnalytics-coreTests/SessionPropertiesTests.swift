import XCTest
@testable import Cognitive3DAnalytics

final class SessionPropertiesTests: XCTestCase {

    var core: MockCognitive3DAnalyticsCore!

    override func setUp() {
        super.setUp()
        core = MockCognitive3DAnalyticsCore()
        try? core.configure(with: CoreSettings(defaultSceneName: "TestScene", apiKey: "test_key"))
        core.clearNewSessionProperties()
    }

    override func tearDown() {
        core.clearNewSessionProperties()
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testSetAndGetProperties() {
        // Set various property types
        core.setSessionProperty(key: "stringKey", value: "string value")
        core.setSessionProperty(key: "intKey", value: 42)
        core.setSessionProperty(key: "boolKey", value: true)
        core.setSessionProperty(key: "doubleKey", value: 3.14159)

        // Get without clearing
        let props = core.getNewSessionProperties()

        // Verify all properties exist
        XCTAssertEqual(props["stringKey"] as? String, "string value")
        XCTAssertEqual(props["intKey"] as? Int, 42)
        XCTAssertEqual(props["boolKey"] as? Bool, true)
        XCTAssertEqual(props["doubleKey"] as? Double, 3.14159)

        // Verify properties are still there
        let propsAgain = core.getNewSessionProperties()
        XCTAssertEqual(propsAgain.count, 4)
    }

    func testGetAndClearProperties() {
        // Set a property
        core.setSessionProperty(key: "testKey", value: "test value")

        // Get with clearing
        let props = core.getNewSessionProperties(clear: true)

        // Verify property was returned
        XCTAssertEqual(props["testKey"] as? String, "test value")

        // Verify properties were cleared
        let emptyProps = core.getNewSessionProperties()
        XCTAssertTrue(emptyProps.isEmpty)
    }

    func testPropertyOverwriting() {
        // Set property
        core.setSessionProperty(key: "key", value: "value1")

        // Overwrite same property
        core.setSessionProperty(key: "key", value: "value2")

        // Verify only latest value exists
        let props = core.getNewSessionProperties()
        XCTAssertEqual(props["key"] as? String, "value2")
        XCTAssertEqual(props.count, 1)
    }

    func testAllSessionPropertiesRetained() {
        // Set property
        core.setSessionProperty(key: "testKey", value: "test value")

        // Clear new properties
        _ = core.getNewSessionProperties(clear: true)

        // Set new property
        core.setSessionProperty(key: "anotherKey", value: "another value")

        // Both should be in allSessionProperties
        XCTAssertEqual(core.allSessionProperties["testKey"] as? String, "test value")
        XCTAssertEqual(core.allSessionProperties["anotherKey"] as? String, "another value")

        // Only the new one should be in newSessionProperties
        let props = core.getNewSessionProperties()
        XCTAssertNil(props["testKey"])
        XCTAssertEqual(props["anotherKey"] as? String, "another value")
    }

    // MARK: - Complex Types

    func testComplexPropertyTypes() {
        // Test array type
        let arrayVal = [1, 2, 3, 4]
        core.setSessionProperty(key: "arrayKey", value: arrayVal)

        // Test dictionary type
        let dictVal = ["a": 1, "b": 2]
        core.setSessionProperty(key: "dictKey", value: dictVal)

        // Get properties
        let props = core.getNewSessionProperties()

        // Verify array property
        XCTAssertEqual(props["arrayKey"] as? [Int], arrayVal)

        // Verify dictionary property
        XCTAssertEqual(props["dictKey"] as? [String: Int], dictVal)
    }

    // MARK: - Session Tags

    func testSessionTagFeature() {
        // Test valid tag
        let validTag = "validTag"
        core.setSessionTag(validTag)

        // Verify tag was set with expected key format
        let props = core.getNewSessionProperties()
        XCTAssertEqual(props["c3d.session_tag.\(validTag)"] as? Bool, true)

        // Test empty tag (should be rejected)
        core.setSessionTag("")

        // Verify empty tag wasn't set
        let propsAfterEmpty = core.getNewSessionProperties()
        XCTAssertNil(propsAfterEmpty["c3d.session_tag."])

        // Test tag that's too long (should be rejected)
        let longTag = "thisTagIsTooLong"
        core.setSessionTag(longTag)

        // Verify long tag wasn't set
        let propsAfterLong = core.getNewSessionProperties()
        XCTAssertNil(propsAfterLong["c3d.session_tag.\(longTag)"])
    }

    // MARK: - Clear Properties

    func testClearNewSessionProperties() {
        // Set several properties
        core.setSessionProperty(key: "key1", value: "value1")
        core.setSessionProperty(key: "key2", value: "value2")

        // Verify they were set
        XCTAssertEqual(core.getNewSessionProperties().count, 2)

        // Clear properties
        core.clearNewSessionProperties()

        // Verify they were cleared
        XCTAssertTrue(core.getNewSessionProperties().isEmpty)
    }

    // MARK: - Edge Cases

    func testEmptyKeyHandling() {
        // Set property with empty key (if your implementation allows it)
        core.setSessionProperty(key: "", value: "test")

        // Get properties
        let props = core.getNewSessionProperties()

        // Check if empty key was handled appropriately
        // (depending on your implementation, this may or may not work)
        if let emptyKeyValue = props[""] as? String {
            XCTAssertEqual(emptyKeyValue, "test")
        }
        // Otherwise the test will pass without assertion
    }

    func testSpecialCharactersInKey() {
        // Test special characters in keys
        let specialKey = "!@#$%^&*()_+"
        core.setSessionProperty(key: specialKey, value: "special value")

        // Get properties
        let props = core.getNewSessionProperties()

        // Verify special character key works
        XCTAssertEqual(props[specialKey] as? String, "special value")
    }
}
