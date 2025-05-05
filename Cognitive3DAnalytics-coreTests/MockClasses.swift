//
//  MockClasses.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// MARK: - Mock Classes for Testing
class MockNetworkAPIClient: NetworkAPIClient {
    // Track request details for verification
    var lastEndpoint: String?
    var lastMethod: HTTPMethod?
    var lastRawBody: Data?
    var shouldSucceed = true

    override func makeRequest<T: Decodable, U: Encodable>(
        endpoint: String,
        sceneId: String,
        version: String,
        method: HTTPMethod = .post,
        body: U? = nil
    ) async throws -> T {
        // Track the request
        lastEndpoint = endpoint
        lastMethod = method

        // Check if we should fail the request
        if !shouldSucceed {
            throw APIError.unauthorized
        }

        // For ExitPollResponse type, return a mock exit poll response
        if T.self == ExitPollResponse.self {
            // Create a mock response using the proper initializer parameters
            let mockResponse = ExitPollResponse(
                id: "test_id",
                projectId: 123,
                name: "test_set",
                customerId: "test_customer",
                status: "active",
                title: "Test Survey",
                version: 1,
                questions: []
            )
            return mockResponse as! T
        } else if T.self == EventResponse.self {
            return EventResponse(status: "200", received: true) as! T
        }

        // Default for other types
        throw APIError.invalidResponse
    }

    // Override the rawBody version of makeRequest
    override func makeRequest<T: Decodable>(
        endpoint: String,
        sceneId: String,
        version: String,
        method: HTTPMethod = .post,
        rawBody: Data?
    ) async throws -> T {
        // Track the request
        lastEndpoint = endpoint
        lastMethod = method
        lastRawBody = rawBody

        // Check if we should fail the request
        if !shouldSucceed {
            throw APIError.unauthorized
        }

        // Return appropriate mock responses based on type
        if T.self == EventResponse.self {
            return EventResponse(status: "200", received: true) as! T
        } else if T.self == ExitPollResponse.self {
            // Create a mock response using the proper initializer parameters
            let mockResponse = ExitPollResponse(
                id: "test_id",
                projectId: 123,
                name: "test_set",
                customerId: "test_customer",
                status: "active",
                title: "Test Survey",
                version: 1,
                questions: []
            )
            return mockResponse as! T
        }

        // Default response for other types
        let mockJSON = """
        {"status": "success"}
        """
        let mockData = mockJSON.data(using: .utf8)!
        return try JSONDecoder().decode(T.self, from: mockData)
    }
}

class MockCognitive3DAnalyticsCore: Cognitive3DAnalyticsCore {
    // Storage for test data cache
    private var testDataCacheSystem: DataCacheSystem?

    // Custom initializer for testing with data cache
    convenience init(withTestDataCache: Bool = false) {
        self.init()

        if withTestDataCache {
            // Create the data cache system directly
            let tempDir = NSTemporaryDirectory() + "TestCache-\(UUID().uuidString)/"
            try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

            // Create the cache synchronously
            let cache = DataCacheSystem()

            // Store cache for later access
            self.testDataCacheSystem = cache

            // Set up the cache path asynchronously
            Task {
                do {
                    try await cache.setCachePath(tempDir)
                    // Also set it on the core so the real dataCacheSystem reference is used
                    self.setDataCacheSystemForTesting(cache)
                } catch {
                    print("Error setting cache path: \(error)")
                }
            }
        }
    }

    // Getter for test data cache
    func getTestDataCacheSystem() -> DataCacheSystem? {
        return testDataCacheSystem
    }

    // Method to set data cache for testing
    func setDataCacheSystemForTesting(_ cache: DataCacheSystem) {
        // Since we can't directly access the private property,
        // just store the cache in our test property
        self.testDataCacheSystem = cache
    }

    // Override the dataCacheSystem getter to use our test cache
    override var dataCacheSystem: DataCacheSystem? {
        return testDataCacheSystem ?? super.dataCacheSystem
    }

    func configure(with settings: CoreSettings) throws {
        config = Config()
        config?.customEventBatchSize = 10
        config?.applicationKey = "test_key"

        // Set up mock scene data
        let mockSceneData = SceneData(
            sceneName: "TestScene",
            sceneId: "test123",
            versionNumber: 1,
            versionId: 1
        )

        // Initialize logger
        logger = CognitiveLog()
        logger?.isDebugVerbose = true

        // Now configure the sensor recorder using configureSensorRecording
        configureSensorRecording(mockSceneData)
        isSessionActive = false
    }

    override var isSessionActive: Bool {
        get { return _isSessionActive }
        set { _isSessionActive = newValue }
    }
    private var _isSessionActive: Bool = false

    override func getConfig() -> Config {
        let config = Config()
        config.customEventBatchSize = 10
        return config
    }

    override func getTimestamp() -> Double {
        return Date().timeIntervalSince1970
    }

    override func getSessionTimestamp() -> Double {
        return getTimestamp()
    }

    override func getSessionId() -> String {
        return "test_session"
    }

    override func getUserId() -> String {
        return "test_user"
    }

    func setSessionActive(_ active: Bool) {
        isSessionActive = active
    }

    // Make sensor recorder mutable for testing purposes
    var _sensorRecorder: SensorRecorder?

    override var sensorRecorder: SensorRecorder? {
        return _sensorRecorder ?? super.sensorRecorder
    }

    // Add method to set the sensor recorder for testing
    func setSensorRecorderForTesting(_ recorder: SensorRecorder) {
        _sensorRecorder = recorder
    }
}

// MARK: - Mock SceneData
extension SceneData {
    static var mock: SceneData {
        return SceneData(
            sceneName: "TestScene",
            sceneId: "test123",
            versionNumber: 1,
            versionId: 1
        )
    }
}
