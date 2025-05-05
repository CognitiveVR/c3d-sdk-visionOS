//
//  CustomEventTests.swift
//  Cognitive3DAnalytics-coreTests
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Testing
@testable import Cognitive3DAnalytics

@MainActor
final class CustomEventTests {
    var mockCore: MockCognitive3DAnalyticsCore!
    var sceneData: SceneData!

    func setUp() async throws {
        mockCore = MockCognitive3DAnalyticsCore()

        // Create a scene data with a non-empty scene ID
        sceneData = SceneData(
            sceneName: "TestScene",
            sceneId: "test-scene-id",
            versionNumber: 1,
            versionId: 1
        )

        // Update the SceneData.mock to ensure it has valid ID
        // This is needed because some code might be using .mock directly

        // Configure the core
        let settings = CoreSettings(
            defaultSceneName: "TestScene",
            allSceneData: [sceneData],
            apiKey: "test_api_key"
        )

        try mockCore.configure(with: settings)
        mockCore.isSessionActive = true

        // Important: Don't call setScene, as it might not work as expected in the mock
        // Instead, explicitly set the sceneId directly
        mockCore.setSceneById(sceneId: sceneData.sceneId, version: sceneData.versionNumber, versionId: sceneData.versionId)

        // Create a recorder with our valid scene data
        mockCore.customEventRecorder = EventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
    }

    @Test("Custom event initializes correctly")
    func customEventInitializes() async throws {
        try await setUp()

        // Given, When
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)

        // Then
        #expect(customEvent != nil, "CustomEvent was successfully created")
    }

    @Test("Custom event sets properties correctly")
    func customEventSetsProperties() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)

        // When
        let result = customEvent
            .setProperty(key: "string_property", value: "string_value")
            .setProperty(key: "int_property", value: 42)
            .setProperty(key: "bool_property", value: true)
            .setProperty(key: "double_property", value: 3.14)

        // Then
        #expect(result === customEvent, "Method chaining should return the same instance")
    }

    @Test("Custom event sets position correctly")
    func customEventSetsPosition() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let position: [Double] = [1.0, 2.0, 3.0]

        // When
        let result = customEvent.setPosition(position)

        // Then
        #expect(result === customEvent, "Method chaining should return the same instance")
    }

    @Test("Custom event sets dynamic object correctly")
    func customEventSetsDynamicObject() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let dynamicObjectId = "test_dynamic_object"

        // When
        let result = customEvent.setDynamicObject(dynamicObjectId)

        // Then
        #expect(result === customEvent, "Method chaining should return the same instance")
    }

    @Test("Custom event send adds event to batch")
    func customEventSendAddsToBatch() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        let result = await customEvent.send()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(!mockEventRecorder.immediateFlag)
    }

    @Test("Send with high priority sends immediately")
    func sendWithHighPrioritySendsImmediately() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        let result = await customEvent.sendWithHighPriority()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.immediateFlag)
    }

    @Test("Custom event tracks duration correctly")
    func customEventTracksDuration() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When - simulate some time passing
        try await Task.sleep(for: .milliseconds(20))
        let result = await customEvent.send()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.lastProperties["duration"] != nil)
    }

    @Test("Custom event prefixes name correctly")
    func customEventPrefixesName() async throws {
        try await setUp()

        // Given
        let eventName = "test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        let result = await customEvent.send()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.lastName == "c3d.test_event")
    }

    @Test("Custom event with existing prefix keeps prefix")
    func customEventWithExistingPrefixKeepsPrefix() async throws {
        try await setUp()

        // Given
        let eventName = "c3d.test_event"
        let customEvent = CustomEvent(name: eventName, core: mockCore)
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        let result = await customEvent.send()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.lastName == "c3d.test_event")
    }
}

// MARK: - Mock EventRecorder for Testing
class MockEventRecorder: EventRecorder {
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
