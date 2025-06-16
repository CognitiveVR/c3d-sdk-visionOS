//
//  SensorRecorderTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
import Foundation
@testable import Cognitive3DAnalytics

// Custom mock implementation that overrides critical methods for testing
final class MockSensorRecorder: SensorRecorder {
    // Track method calls
    var sendDataCalled = false
    var recordedValues: [String: [Double]] = [:]

    // Override recordDataPoint to track values without calling super
    @discardableResult
    override public func recordDataPoint(name: String, value: Double) -> Bool {
        // Skip filtering to ensure all test values are recorded
        filteringEnabled = false

        // Track the sensor and value
        if recordedValues[name] == nil {
            recordedValues[name] = []
        }
        recordedValues[name]?.append(value)

        // Call the real method to trigger batch processing
        let result = super.recordDataPoint(name: name, value: value)

        return result
    }

    // Override sendData to track when it's called
    @discardableResult
    override internal func sendData() async -> Sensor? {
        // Mark that this was called
        sendDataCalled = true

        // Return a mock sensor for testing
        let mockSensor = Sensor(
            userId: "test_user",
            timestamp: Date().timeIntervalSince1970,
            sessionId: "test_session",
            part: 1,
            formatVersion: "1.0",
            sessionType: "sensor",
            data: []
        )

        return mockSensor
    }
}

// Helper to create a test environment
struct SensorTestEnvironment {
    let mockCore: MockCognitive3DAnalyticsCore
    let sensorRecorder: MockSensorRecorder
    let mockSceneData: SceneData

    init() {
        mockCore = MockCognitive3DAnalyticsCore()
        mockSceneData = SceneData.mock
        try? mockCore.configure(with: CoreSettings(
            defaultSceneName: "TestScene",
            allSceneData: [mockSceneData],
            apiKey: "test_key"
        ))
        mockCore.setSessionActive(true)

        // Initialize our mock sensor recorder
        sensorRecorder = MockSensorRecorder(cog: mockCore, sceneData: mockSceneData)

        // Ensure the mock core uses our mock recorder
        mockCore.setSensorRecorderForTesting(sensorRecorder)
    }
}

@Suite("Sensor Recorder Tests")
struct SensorRecorderTests {

    @Test("Basic sensor recording should succeed when session is active")
    func testBasicSensorRecording() {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let sensorName = "test_sensor"
        let sensorValue = 42.0

        // When
        let result = env.sensorRecorder.recordDataPoint(name: sensorName, value: sensorValue)

        // Then
        #expect(result, "Recording should succeed")
        #expect(env.sensorRecorder.recordedValues[sensorName] != nil, "Sensor should be recorded")
        #expect(env.sensorRecorder.recordedValues[sensorName]?.first == sensorValue, "Value should match")
    }

    @Test("Sensor recording should fail when session is inactive")
    func testSensorRecordingWhileSessionInactive() {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        env.mockCore.setSessionActive(false)
        let sensorName = "test_sensor"
        let sensorValue = 42.0

        // When
        let result = env.sensorRecorder.recordDataPoint(name: sensorName, value: sensorValue)

        // Then
        #expect(!result, "Recording should fail when session is inactive")
    }

    @Test("Concurrent sensor recording from multiple threads should work correctly")
    func testConcurrentSensorRecording() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Reset the sendDataCalled flag
        env.sensorRecorder.sendDataCalled = false

        // Given
        let iterations = 100 // Reduced from 1000 to avoid overwhelming the test environment

        // When - Create tasks that don't capture self
        let sensor1Task = Task<Void, Never> {
            for i in 0..<iterations {
                _ = env.sensorRecorder.recordDataPoint(name: "sensor1", value: Double(i))
            }
        }

        let sensor2Task = Task<Void, Never> {
            for i in 0..<iterations {
                _ = env.sensorRecorder.recordDataPoint(name: "sensor2", value: Double(i))
            }
        }

        // Wait for both tasks to complete
        _ = await (sensor1Task.value, sensor2Task.value)

        // Wait a bit for the async sendData call to be processed
        try await Task.sleep(for: .seconds(1))

        // Then
        #expect(env.sensorRecorder.sendDataCalled, "The sendData method should have been called")
    }

    @Test("Rapid session state changes should be handled correctly")
    func testRapidSessionStateChanges() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let iterations = 10
        let sensorName = "test_sensor"

        // When
        for i in 0..<iterations {
            // Simply toggle the session state directly
            env.mockCore.setSessionActive(true)
            _ = env.sensorRecorder.recordDataPoint(name: sensorName, value: Double(i))
            env.mockCore.setSessionActive(false)

            // Add a small delay to avoid overwhelming the system
            try await Task.sleep(for: .nanoseconds(1_000_000))
        }

        // Then - Test passes if no exceptions are thrown
    }

    @Test("Multiple sensors with concurrent session changes should work correctly")
    func testMultipleSensorsWithSessionChanges() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let iterations = 50 // Reduced from 100 to avoid overwhelming the test environment

        // Create a capture-free sensor recording task
        let sensor1Task = Task<Void, Never> {
            for i in 0..<iterations {
                _ = env.sensorRecorder.recordDataPoint(name: "sensor1", value: Double(i))
                try? await Task.sleep(for: .nanoseconds(1_000_000)) // 1ms delay
            }
        }

        let sensor2Task = Task<Void, Never> {
            for i in 0..<iterations {
                _ = env.sensorRecorder.recordDataPoint(name: "sensor2", value: Double(i))
                try? await Task.sleep(for: .nanoseconds(1_000_000)) // 1ms delay
            }
        }

        let sessionTask = Task<Void, Never> {
            for _ in 0..<5 {
                env.mockCore.setSessionActive(false)
                try? await Task.sleep(for: .nanoseconds(10_000_000)) // 10ms delay
                env.mockCore.setSessionActive(true)
            }
        }

        // Wait for all tasks to complete
        _ = await (sensor1Task.value, sensor2Task.value, sessionTask.value)

        // Then - Test passes if no exceptions are thrown
    }

    @Test("Sensor data model should correctly encode and decode")
    func testSensorDataModel() throws {
        // Given
        let timestamp = Date().timeIntervalSince1970
        let sensorData = Sensor(
            userId: "test_user",
            timestamp: timestamp,
            sessionId: "test_session",
            part: 1,
            formatVersion: "1.0",
            sessionType: "sensor",
            data: [SensorEventData(name: "test_sensor", data: [[timestamp, 42.0]])]
        )

        // When
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(sensorData)
        let decoded = try decoder.decode(Sensor.self, from: data)

        // Then
        #expect(decoded.userId == "test_user", "User ID should match")
        #expect(decoded.sessionId == "test_session", "Session ID should match")
        #expect(decoded.data.first?.name == "test_sensor", "Sensor name should match")
        #expect(decoded.data.first?.data.first?[1] == 42.0, "Sensor value should match")
    }

    @Test("Batch size should trigger data upload when reached")
    func testBatchSizeTriggering() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let batchSize = env.mockCore.getConfig().customEventBatchSize
        let sensorName = "test_sensor"

        // Reset the flag
        env.sensorRecorder.sendDataCalled = false

        // When
        for i in 0..<(batchSize + 1) {
            _ = env.sensorRecorder.recordDataPoint(name: sensorName, value: Double(i))
        }

        // Wait a bit for async operations to complete
        try await Task.sleep(for: .seconds(1))

        // Then
        #expect(env.sensorRecorder.sendDataCalled, "The sendData method should have been called when batch size was reached")
    }

    @Test("End session should clean up resources properly")
    func testEndSessionCleanup() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let sensorName = "test_sensor"

        // Record some data
        for i in 0..<5 {
            _ = env.sensorRecorder.recordDataPoint(name: sensorName, value: Double(i))
        }

        // Reset the flag
        env.sensorRecorder.sendDataCalled = false

        // When
        await env.sensorRecorder.endSession()

        // Try recording after session end
        env.mockCore.setSessionActive(true)
        _ = env.sensorRecorder.recordDataPoint(name: sensorName, value: 100.0)

        // Then - test passes if no exceptions are thrown
    }

    @Test("Sensor recorder should be thread-safe")
    func testSensorRecorderThreadSafety() async throws {
        // Setup test environment
        let env = SensorTestEnvironment()

        // Given
        let iterations = 100
        let sensorCount = 5
        let tasks = (0..<sensorCount).map { sensorIndex in
            Task<Void, Never> {
                for i in 0..<iterations {
                    _ = env.sensorRecorder.recordDataPoint(
                        name: "sensor\(sensorIndex)",
                        value: Double(i)
                    )
                }
            }
        }

        // Wait for all tasks to complete
        for task in tasks {
            _ = await task.value
        }

        // Then - just verify it didn't crash
    }
}
