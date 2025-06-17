//
//  EventTests.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-11-28.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import XCTest

@testable import Cognitive3DAnalytics

/// Unit tests for the custom event type.
final class EventTests: XCTestCase {
    // MARK: - Test Constants
    private enum Constants {
        static let timestamp = 1637932800.0
        static let formatVersion = "1.0"
        static let defaultPoint = [1.0, 2.0, 3.0]
    }

    // MARK: - Test Properties
    private var encoder: JSONEncoder!
    private var testUserId: String!
    private var testSessionId: String!

    // MARK: - Setup and Teardown
    override func setUp() {
        super.setUp()
        encoder = JSONEncoder()
        testUserId = UUID().uuidString
        testSessionId = "\(Int(floor(Constants.timestamp)))_\(testUserId!)"
    }

    override func tearDown() {
        encoder = nil
        testUserId = nil
        testSessionId = nil
        super.tearDown()
    }

    // MARK: - Helper Methods
    private func createTestEvent(
        userId: String? = nil,
        timestamp: Double = Constants.timestamp,
        sessionId: String? = nil,
        part: Int = 1,
        formatVersion: String = Constants.formatVersion,
        eventData: [EventData]
    ) -> Event {
        Event(
            userId: userId ?? testUserId,
            timestamp: timestamp,
            sessionId: sessionId ?? testSessionId,
            part: part,
            formatVersion: formatVersion,
            data: eventData
        )
    }

    private func createTestEventData(
        name: String,
        time: Double = Constants.timestamp + 1,
        point: [Double] = Constants.defaultPoint,
        properties: [String: FreeformData]? = nil
    ) -> EventData {
        EventData(
            name: name,
            time: time,
            point: point,
            properties: properties,
            dynamicObjectId: "ABCD1234"
        )
    }

    private func verifyEventJSON(_ json: [String: Any], expectedEvent: Event) {
        XCTAssertEqual(json["userid"] as? String, expectedEvent.userId)
        XCTAssertEqual(json["sessionid"] as? String, expectedEvent.sessionId)
        XCTAssertEqual(json["formatversion"] as? String, expectedEvent.formatVersion)
        XCTAssertEqual(json["part"] as? Int, expectedEvent.part)
    }

    private func verifyEventDataJSON(_ json: [String: Any], expectedEventData: EventData) {
        XCTAssertEqual(json["name"] as? String, expectedEventData.name)
        XCTAssertEqual(json["time"] as? Double, expectedEventData.time)
        XCTAssertEqual(json["point"] as? [Double], expectedEventData.point)
    }

    private func verifyProperty(
        _ decodedValue: Any?, expectedValue: FreeformData, file: StaticString = #file, line: UInt = #line
    ) {
        switch expectedValue {
        case .string(let value):
            XCTAssertEqual(decodedValue as? String, value, file: file, line: line)
        case .number(let value):
            XCTAssertEqual(decodedValue as? Double, value, file: file, line: line)
        case .integer(let value):
            XCTAssertEqual(decodedValue as? Int, value, file: file, line: line)
        case .boolean(let value):
            XCTAssertEqual(decodedValue as? Bool, value, file: file, line: line)
        case .array(let value):
            guard let decodedArray = decodedValue as? [Any] else {
                XCTFail("Expected array value", file: file, line: line)
                return
            }
            for (index, element) in value.enumerated() {
                verifyProperty(decodedArray[index], expectedValue: element, file: file, line: line)
            }
        case .object(let value):
            guard let decodedObject = decodedValue as? [String: Any] else {
                XCTFail("Expected object value", file: file, line: line)
                return
            }
            for (key, element) in value {
                verifyProperty(decodedObject[key], expectedValue: element, file: file, line: line)
            }
        case .null:
            XCTAssertTrue(decodedValue is NSNull, file: file, line: line)
        }
    }

    // MARK: - Tests
    func testBasicEventEncoding() throws {
        // Given
        let eventData = createTestEventData(name: "test-event")
        let event = createTestEvent(eventData: [eventData])

        // When
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        verifyEventJSON(json!, expectedEvent: event)

        if let eventDataArray = json?["data"] as? [[String: Any]], let firstEvent = eventDataArray.first {
            verifyEventDataJSON(firstEvent, expectedEventData: eventData)
        } else {
            XCTFail("Failed to decode event data array")
        }
    }

    func testEventDataWithProperties() throws {
        // Given
        let testCases: [(String, [String: FreeformData])] = [
            (
                "Basic Types",
                [
                    "string": .string("test"),
                    "number": .number(42.5),
                    "integer": .integer(42),
                    "boolean": .boolean(true),
                    "null": .null,
                ]
            ),
            (
                "Array Types",
                [
                    "simpleArray": .array([.string("item1"), .number(2.0)]),
                    "nestedArray": .array([.array([.string("nested"), .number(3.0)])]),
                ]
            ),
            (
                "Object Types",
                [
                    "simpleObject": .object(["key": .string("value")]),
                    "nestedObject": .object([
                        "nested": .object([
                            "deepKey": .string("deepValue")
                        ])
                    ]),
                ]
            ),
        ]

        for (testName, properties) in testCases {
            // When
            let eventData = createTestEventData(name: "test-\(testName)", properties: properties)
            let data = try encoder.encode(eventData)
            let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            // Then
            verifyEventDataJSON(decoded, expectedEventData: eventData)

            if let decodedProperties = decoded["properties"] as? [String: Any] {
                for (key, expectedValue) in properties {
                    verifyProperty(decodedProperties[key], expectedValue: expectedValue)
                }
            } else {
                XCTFail("Failed to decode properties for test case: \(testName)")
            }
        }
    }

    /// Unit test using real data
    func testFactorySceneEventDecoding() throws {
        // Given
        let timestamp = 1581442899.81398
        let userId = "6f89ecadc3a44ea3748f380552d608b1e911d074"

        let eventData1 = createTestEventData(
            name: "c3d.SceneChange",
            time: 1581442904.23179,
            point: [-4.65433, 1.6369, -4.7159],
            properties: [
                "Duration": .number(2.007557),
                "Scene Name": .string("factory scene"),
                "Scene Id": .string("cc508973-eaff-4055-8644-233f5d8c7bba"),
            ]
        )

        let eventData2 = createTestEventData(
            name: "c3d.sessionStart",
            time: 1581442904.23179,
            point: [-4.65433, 1.6369, -4.7159]
        )

        let event = createTestEvent(
            userId: userId,
            timestamp: timestamp,
            sessionId: "\(Int(floor(timestamp)))_\(userId)",
            part: 8,
            eventData: [eventData1, eventData2]
        )

        // When
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        verifyEventJSON(json!, expectedEvent: event)

        guard let eventDataArray = json?["data"] as? [[String: Any]] else {
            XCTFail("Failed to decode event data array")
            return
        }

        XCTAssertEqual(eventDataArray.count, 2, "Should contain exactly 2 events")
        verifyEventDataJSON(eventDataArray[0], expectedEventData: eventData1)
        verifyEventDataJSON(eventDataArray[1], expectedEventData: eventData2)

        // Verify properties of first event
        if let properties = eventDataArray[0]["properties"] as? [String: Any] {
            XCTAssertEqual(properties["Duration"] as? Double, 2.007557)
            XCTAssertEqual(properties["Scene Name"] as? String, "factory scene")
            XCTAssertEqual(properties["Scene Id"] as? String, "cc508973-eaff-4055-8644-233f5d8c7bba")
        } else {
            XCTFail("Failed to decode properties for SceneChange event")
        }
    }

    /// Unit test using real data
    func testGameSessionEventDecoding() throws {
        // Given
        let timestamp = 1732210233.696
        let userId = "5b5bf7747b54905cdfc70b71a65b8114"

        let eventData1 = createTestEventData(
            name: "Time To Fun",
            time: 1732210233.696,
            point: [0, 0.009990000165998936, -1.7400000095367432],
            properties: [
                "duration": .number(27.41107940673828)
            ]
        )

        let eventData2 = createTestEventData(
            name: "Movement Changed",
            time: 1732210244.836,
            point: [0.23543000221252441, 1.5615099668502808, -2.210510015487671],
            properties: [
                "CurrentMovementType": .string("Teleportation Movement")
            ]
        )

        let event = createTestEvent(
            userId: userId,
            timestamp: timestamp,
            sessionId: "\(Int(floor(timestamp)))_\(userId)",
            part: 1,
            eventData: [eventData1, eventData2]
        )

        // When
        let data = try encoder.encode(event)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Then
        XCTAssertNotNil(json)
        verifyEventJSON(json!, expectedEvent: event)

        guard let eventDataArray = json?["data"] as? [[String: Any]] else {
            XCTFail("Failed to decode event data array")
            return
        }

        XCTAssertEqual(eventDataArray.count, 2, "Should contain exactly 2 events")
        verifyEventDataJSON(eventDataArray[0], expectedEventData: eventData1)
        verifyEventDataJSON(eventDataArray[1], expectedEventData: eventData2)

        // Verify properties of first event
        if let properties = eventDataArray[0]["properties"] as? [String: Any] {
            XCTAssertEqual(properties["duration"] as? Double, 27.41107940673828)
        } else {
            XCTFail("Failed to decode properties for Time To Fun event")
        }

        // Verify properties of second event
        if let properties = eventDataArray[1]["properties"] as? [String: Any] {
            XCTAssertEqual(properties["CurrentMovementType"] as? String, "Teleportation Movement")
        } else {
            XCTFail("Failed to decode properties for Movement Changed event")
        }
    }

    func testInvalidJSONValueDecoding() {
        let invalidJSON = """
            {
                "invalid": Date()
            }
            """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode([String: FreeformData].self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testUniqueUserIdGeneration() {
        // Given
        let eventData1 = createTestEventData(name: "test-event-1")
        let eventData2 = createTestEventData(name: "test-event-2")

        // When
        let event1 = createTestEvent(eventData: [eventData1])
        testUserId = UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        testSessionId = "\(Int(floor(Constants.timestamp)))_\(testUserId!)"

        let event2 = createTestEvent(eventData: [eventData2])

        // Then
        XCTAssertNotEqual(event1.userId, event2.userId, "User IDs should be unique")
        XCTAssertNotEqual(event1.sessionId, event2.sessionId, "Session IDs should be unique")

        // Verify session ID format
        let sessionIdComponents1 = event1.sessionId.split(separator: "_")
        let sessionIdComponents2 = event2.sessionId.split(separator: "_")

        XCTAssertEqual(sessionIdComponents1.count, 2, "Session ID should have timestamp and UUID parts")
        XCTAssertEqual(sessionIdComponents2.count, 2, "Session ID should have timestamp and UUID parts")

        XCTAssertEqual(
            sessionIdComponents1[0], "\(Int(floor(Constants.timestamp)))", "Timestamp should be without fractional part"
        )
        XCTAssertEqual(
            sessionIdComponents2[0], "\(Int(floor(Constants.timestamp)))", "Timestamp should be without fractional part"
        )
    }
}
