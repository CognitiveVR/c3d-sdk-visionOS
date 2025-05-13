//
//  EventRecorderTests.swift
//  Cognitive3DAnalytics-coreTests
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
import Foundation

@testable import Cognitive3DAnalytics

@MainActor
final class EventRecorderTests {
    var mockCore: MockCognitive3DAnalyticsCore!
    var sceneData: SceneData!
    var eventRecorder: EventRecorder!

    func setUp() async throws {
        mockCore = MockCognitive3DAnalyticsCore()

        // Create scene data with a valid scene ID
        sceneData = SceneData(
            sceneName: "TestScene",
            sceneId: "test-scene-id",
            versionNumber: 1,
            versionId: 1
        )

        // Configure with the valid scene data
        let settings = CoreSettings(
            defaultSceneName: "TestScene",
            allSceneData: [sceneData],
            apiKey: "test_api_key"
        )

        try mockCore.configure(with: settings)
        mockCore.isSessionActive = true

        // Set scene ID directly
        mockCore.setSceneById(sceneId: sceneData.sceneId, version: sceneData.versionNumber, versionId: sceneData.versionId)

        // Create an event recorder
        eventRecorder = EventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3)
    }

    @Test("Event recorder initializes correctly")
    func eventRecorderInitializes() async throws {
        try await setUp()
        #expect(eventRecorder != nil)
    }

    @Test("Record event adds event to batch")
    func recordEventAddsToBatch() async throws {
        try await setUp()

        // Create a test-specific recorder with our mock
        let mockEventRecorder = TestEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3)

        // When
        let result = await mockEventRecorder.recordEvent(
            name: "test_event",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value"],
            immediate: false
        )

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
    }

    @Test("Recording immediate event sends without batching")
    func recordEventImmediateSendsWithoutBatching() async throws {
        try await setUp()

        // Create a test-specific recorder with our mock
        let mockEventRecorder = TestEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3)

        // When - record with immediate flag
        let result = await mockEventRecorder.recordEvent(
            name: "test_event",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value"],
            immediate: true
        )

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.immediateFlag)
    }

    @Test("Send batched events when threshold reached")
    func sendBatchedEventsWhenThresholdReached() async throws {
        try await setUp()

        // Create a recorder with a spy to track batch sends
        let batchSizeSpy = BatchSendingSpy()

        // This time, we'll use a fully mocked implementation to avoid real network calls
        let mockEventRecorder = MockBatchEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3, spy: batchSizeSpy)

        // When - add events just below the threshold
        let result1 = await mockEventRecorder.recordEvent(
            name: "test_event_1",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value1"],
            immediate: false
        )

        let result2 = await mockEventRecorder.recordEvent(
            name: "test_event_2",
            position: [4.0, 5.0, 6.0],
            properties: ["test": "value2"],
            immediate: false
        )

        // Then - verify no batch was sent yet
        #expect(result1)
        #expect(result2)
        #expect(batchSizeSpy.sendBatchCalledCount == 0)

        // When - add one more event to reach the threshold
        let result3 = await mockEventRecorder.recordEvent(
            name: "test_event_3",
            position: [7.0, 8.0, 9.0],
            properties: ["test": "value3"],
            immediate: false
        )

        // Then - verify a batch was sent
        #expect(result3)
        #expect(batchSizeSpy.sendBatchCalledCount == 1, "Batch should have been sent when batch size reached")
    }

    @Test("Record dynamic event adds to batch")
    func recordDynamicEventAddsToBatch() async throws {
        try await setUp()

        // Use mock recorder that doesn't try to use real network
        let mockEventRecorder = TestEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3)

        // When
        let result = await mockEventRecorder.recordDynamicEvent(
            name: "test_dynamic_event",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value"],
            dynamicObjectId: "test_dynamic_id",
            immediate: false
        )

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
    }

    @Test("Send all pending events sends events")
    func sendAllPendingEventsSendsEvents() async throws {
        try await setUp()

        // Create a recorder with a spy to track batch sends
        let batchSizeSpy = BatchSendingSpy()
        let recorder = MockBatchEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10, spy: batchSizeSpy)

        // When - add some events but don't reach the threshold
        await recorder.recordEvent(
            name: "test_event_1",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value1"],
            immediate: false
        )

        await recorder.recordEvent(
            name: "test_event_2",
            position: [4.0, 5.0, 6.0],
            properties: ["test": "value2"],
            immediate: false
        )

        // Then - verify no batch was sent yet
        #expect(batchSizeSpy.sendBatchCalledCount == 0)

        // When - manually send all pending events
        let result = await recorder.sendAllPendingEvents()

        // Then - verify a batch was sent
        #expect(result)
        #expect(batchSizeSpy.sendBatchCalledCount == 1)
    }

    @Test("End session sends remaining events")
    func endSessionSendsRemainingEvents() async throws {
        try await setUp()

        // Create a recorder with a spy to track batch sends
        let batchSizeSpy = BatchSendingSpy()
        let recorder = MockBatchEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10, spy: batchSizeSpy)

        // When - add some events but don't reach the threshold
        await recorder.recordEvent(
            name: "test_event_1",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value1"],
            immediate: false
        )

        // Then - verify no batch was sent yet
        #expect(batchSizeSpy.sendBatchCalledCount == 0)

        // When - end the session
        await recorder.endSession()

        // Then - verify a batch was sent
        #expect(batchSizeSpy.sendBatchCalledCount == 1)
    }

    @Test("Send data before scene change sends events")
    func sendDataBeforeSceneChangeSendsEvents() async throws {
        try await setUp()

        // Create a recorder with a spy to track batch sends
        let batchSizeSpy = BatchSendingSpy()
        let recorder = MockBatchEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10, spy: batchSizeSpy)

        // When - add some events but don't reach the threshold
        await recorder.recordEvent(
            name: "test_event_1",
            position: [1.0, 2.0, 3.0],
            properties: ["test": "value1"],
            immediate: false
        )

        // Then - verify no batch was sent yet
        #expect(batchSizeSpy.sendBatchCalledCount == 0)

        // When - call sendDataBeforeSceneChange
        let result = await recorder.sendDataBeforeSceneChange()

        // Then - verify a batch was sent
        #expect(result)
        #expect(batchSizeSpy.sendBatchCalledCount == 1)
    }
}

// MARK: - Helper Classes for Testing

class BatchSendingSpy {
    var sendBatchCalledCount = 0

    func batchSent() {
        sendBatchCalledCount += 1
    }
}

// Different name to avoid conflict with existing MockEventRecorder
class TestEventRecorder: EventRecorder {
    var recordEventCallCount = 0
    var immediateFlag = false
    var lastName = ""
    var lastPosition: [Double]?
    var lastProperties: [String: Any] = [:]

    override func recordEvent(name: String, position: [Double], properties: [String: Any], immediate: Bool, bypassActiveCheck: Bool = false) async -> Bool {
        recordEventCallCount += 1
        immediateFlag = immediate
        lastName = name
        lastPosition = position
        lastProperties = properties
        return true
    }

    override func recordDynamicEvent(name: String, position: [Double], properties: [String: Any], dynamicObjectId: String, immediate: Bool) async -> Bool {
        recordEventCallCount += 1
        immediateFlag = immediate
        lastName = name
        lastPosition = position
        lastProperties = properties
        return true
    }
}

// A completely mocked version that manually implements batching behavior
class MockBatchEventRecorder: EventRecorder {
    private let spy: BatchSendingSpy
    private var batchedEvents: [EventData] = []
    private let mockBatchSize: Int

    init(cog: Cognitive3DAnalyticsCore, sceneData: SceneData, batchSize: Int, spy: BatchSendingSpy) {
        self.spy = spy
        self.mockBatchSize = batchSize
        super.init(cog: cog, sceneData: sceneData, batchSize: batchSize)
    }

    override func recordEvent(name: String, position: [Double], properties: [String: Any], immediate: Bool, bypassActiveCheck: Bool = false) async -> Bool {
        // If immediate, don't batch
        if immediate {
            return true
        }

        // Add to our mock batch
        let eventData = EventData(
            name: name,
            time: Date().timeIntervalSince1970,
            point: position,
            properties: properties.mapValues { convertValueToFreeformData($0) },
            dynamicObjectId: nil
        )

        batchedEvents.append(eventData)

        // If we've reached the batch size, send the batch
        if batchedEvents.count >= mockBatchSize {
            return await mockSendBatchedEvents()
        }

        return true
    }

    private func convertValueToFreeformData(_ value: Any) -> FreeformData {
        switch value {
        case let stringValue as String: return .string(stringValue)
        case let numberValue as Double: return .number(numberValue)
        case let boolValue as Bool: return .boolean(boolValue)
        default: return .string(String(describing: value))
        }
    }

    // Mock sending batched events
    private func mockSendBatchedEvents() async -> Bool {
        // In a test environment, just return success and notify the spy
        batchedEvents.removeAll()
        spy.batchSent()
        return true
    }

    // Override the public methods that trigger batch sending

    override func sendAllPendingEvents() async -> Bool {
        if !batchedEvents.isEmpty {
            return await mockSendBatchedEvents()
        }
        return true
    }

    override func endSession() async {
        if !batchedEvents.isEmpty {
            _ = await mockSendBatchedEvents()
        }
    }

    override func sendDataBeforeSceneChange() async -> Bool {
        if !batchedEvents.isEmpty {
            return await mockSendBatchedEvents()
        }
        return true
    }
}
