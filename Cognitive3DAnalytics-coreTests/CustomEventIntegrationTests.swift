//
//  CustomEventIntegrationTests.swift
//  Cognitive3DAnalytics-coreTests
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
import Foundation

@testable import Cognitive3DAnalytics

@MainActor
final class CustomEventIntegrationTests {
    var mockCore: MockCognitive3DAnalyticsCore!
    var sceneData: SceneData!

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

        // Use setSceneById instead of setScene
        mockCore.setSceneById(sceneId: sceneData.sceneId, version: sceneData.versionNumber, versionId: sceneData.versionId)

        // Initialize with a default event recorder using the same scene data
        mockCore.customEventRecorder = EventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 3)
    }

    @Test("Send with high priority sends immediately")
    func sendWithHighPrioritySendsImmediately() async throws {
        try await setUp()

        // Given
        let event = CustomEvent(name: "priority_test", core: mockCore)

        // Create a mock event recorder to capture the immediate flag
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        let result = await event.sendWithHighPriority()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)
        #expect(mockEventRecorder.immediateFlag, "Should use immediate flag")
    }

    @Test("Custom event with all features works correctly")
    func customEventWithAllFeatures() async throws {
        try await setUp()

        // Given
        let event = CustomEvent(name: "complete_test", core: mockCore)
            .setProperty(key: "string_prop", value: "test value")
            .setProperty(key: "number_prop", value: 42)
            .setPosition([10.0, 20.0, 30.0])
            .setDynamicObject("object_id_123")

        // Create a mock event recorder to capture details
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When
        try await Task.sleep(for: .milliseconds(15)) // Add some delay for duration
        let result = await event.send()

        // Then
        #expect(result)
        #expect(mockEventRecorder.recordEventCallCount == 1)

        // Verify properties
        #expect(mockEventRecorder.lastProperties["string_prop"] as? String == "test value")
        #expect(mockEventRecorder.lastProperties["number_prop"] as? Int == 42)
        #expect(mockEventRecorder.lastProperties["duration"] != nil)

        // Verify position and name
        #expect(mockEventRecorder.lastPosition == [10.0, 20.0, 30.0])
        #expect(mockEventRecorder.lastName == "c3d.complete_test")
    }

    @Test("Duration property is added to event properties")
    func verifyDurationProperty() async throws {
        try await setUp()

        // Given - create event
        let event = CustomEvent(name: "duration_test", core: mockCore)

        // Create a mock event recorder that we can inspect
        let mockEventRecorder = MockEventRecorder(cog: mockCore, sceneData: sceneData, batchSize: 10)
        mockCore.customEventRecorder = mockEventRecorder

        // When - wait briefly to ensure measurable duration and then send
        try await Task.sleep(for: .milliseconds(20))
        let success = await event.send()

        // Then
        #expect(success)
        #expect(mockEventRecorder.recordEventCallCount == 1)

        // Check that duration property exists
        let durationProperty = mockEventRecorder.lastProperties["duration"]
        #expect(durationProperty != nil, "Duration property should exist")

        // Verify duration is a TimeInterval with reasonable value
        if let duration = durationProperty as? TimeInterval {
            #expect(duration >= 0.01, "Duration should be at least 10ms")
            #expect(duration < 10.0, "Duration should be less than 10 seconds")
        }
    }
}
