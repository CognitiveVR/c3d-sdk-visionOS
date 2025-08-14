//
//  SimplifiedConfigurationTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
@testable import Cognitive3DAnalytics

@MainActor
struct SimplifiedConfigurationTests {
    
    func setUp() async throws {
        // Reset SDK state before each test
        Cognitive3DAnalyticsCore.reset()
    }
    
    @Test("Builder pattern basic configuration")
    func testBuilderBasicConfiguration() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        // Validate without configuring
        try builder.validate()
        
        // Should not throw
        #expect(true)
    }
    
    @Test("Builder pattern validation catches missing API key")
    func testBuilderValidationMissingAPIKey() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        do {
            try builder.validate()
            Issue.record("Expected validation to fail for missing API key")
        } catch let error as Cognitive3DConfigurationError {
            #expect(error == .missingAPIKey)
        }
    }
    
    @Test("Builder pattern validation catches missing scene data")
    func testBuilderValidationMissingScene() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
        
        do {
            try builder.validate()
            Issue.record("Expected validation to fail for missing scene data")
        } catch let error as Cognitive3DConfigurationError {
            #expect(error == .missingSceneData)
        }
    }
    
    @Test("Builder pattern validation catches invalid API key")
    func testBuilderValidationShortAPIKey() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
            .apiKey("short")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        do {
            try builder.validate()
            Issue.record("Expected validation to fail for short API key")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidAPIKey(let reason) = error {
                #expect(reason.contains("too short"))
            } else {
                Issue.record("Expected invalidAPIKey error")
            }
        }
    }
    
    @Test("Builder pattern validation catches invalid batch sizes")
    func testBuilderValidationInvalidBatchSize() async throws {
        await setUp()
        
        let invalidBatchConfig = BatchSizeConfig(
            gazeBatchSize: 2000, // Too large
            customEventBatchSize: 32,
            fixationBatchSize: 32,
            sensorDataLimit: 32,
            dynamicDataLimit: 32,
            gazeInterval: 0.1,
            sensorAutoSendInterval: 2.0
        )
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
            .batchSizes(invalidBatchConfig)
        
        do {
            try builder.validate()
            Issue.record("Expected validation to fail for invalid batch size")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidBatchSize(let parameter, let value, _) = error {
                #expect(parameter == "gazeBatchSize")
                #expect(value == 2000)
            } else {
                Issue.record("Expected invalidBatchSize error")
            }
        }
    }
    
    @Test("Builder pattern validation catches invalid intervals")
    func testBuilderValidationInvalidInterval() async throws {
        await setUp()
        
        let invalidBatchConfig = BatchSizeConfig(
            gazeBatchSize: 32,
            customEventBatchSize: 32,
            fixationBatchSize: 32,
            sensorDataLimit: 32,
            dynamicDataLimit: 32,
            gazeInterval: 50.0, // Too large
            sensorAutoSendInterval: 2.0
        )
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
            .batchSizes(invalidBatchConfig)
        
        do {
            try builder.validate()
            Issue.record("Expected validation to fail for invalid interval")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidInterval(let parameter, let value, _) = error {
                #expect(parameter == "gazeInterval")
                #expect(value == 50.0)
            } else {
                Issue.record("Expected invalidInterval error")
            }
        }
    }
    
    @Test("Convenience setup method with basic parameters")
    func testConvenienceSetupBasic() async throws {
        await setUp()
        
        // This should not throw in validation
        // Note: Actual configuration will fail without proper scene data
        // but validation should pass
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        try builder.validate()
        #expect(true)
    }
    
    @Test("Batch size presets work correctly")
    func testBatchSizePresets() async throws {
        await setUp()
        
        // Test that all presets are valid
        let defaultConfig = BatchSizeConfig.default
        let performanceConfig = BatchSizeConfig.performance
        let conservativeConfig = BatchSizeConfig.conservative
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        // All presets should validate successfully
        try builder.batchSizes(defaultConfig).validate()
        try builder.batchSizes(performanceConfig).validate()
        try builder.batchSizes(conservativeConfig).validate()
        
        #expect(true)
    }
    
    @Test("Feature toggle presets work correctly")
    func testFeatureTogglePresets() async throws {
        await setUp()
        
        // Test that all presets are valid
        let defaultFeatures = FeatureToggleConfig.default
        let minimalFeatures = FeatureToggleConfig.minimal
        let comprehensiveFeatures = FeatureToggleConfig.comprehensive
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        // All presets should validate successfully
        try builder.features(defaultFeatures).validate()
        try builder.features(minimalFeatures).validate()
        try builder.features(comprehensiveFeatures).validate()
        
        #expect(true)
    }
    
    @Test("Network config presets work correctly")
    func testNetworkConfigPresets() async throws {
        await setUp()
        
        // Test that all presets are valid
        let defaultNetwork = NetworkConfig.default
        let debugNetwork = NetworkConfig.debug
        let networkOnlyConfig = NetworkConfig.networkOnly
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "TestScene", id: "test-scene-id-123")
        
        // All presets should validate successfully
        try builder.network(defaultNetwork).validate()
        try builder.network(debugNetwork).validate()
        try builder.network(networkOnlyConfig).validate()
        
        #expect(true)
    }
    
    @Test("Additional scenes can be added")
    func testAdditionalScenes() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
            .apiKey("test-api-key-12345")
            .scene(name: "MainScene", id: "main-scene-id-123")
            .addScene(name: "SecondScene", id: "second-scene-id-456")
        
        try builder.validate()
        #expect(true)
    }
    
    @Test("Error messages are descriptive")
    func testErrorMessageQuality() async throws {
        await setUp()
        
        let builder = Cognitive3DBuilder()
        
        do {
            try builder.validate()
        } catch let error as Cognitive3DConfigurationError {
            let description = error.errorDescription ?? ""
            let suggestion = error.recoverySuggestion ?? ""
            
            // Error messages should be descriptive
            #expect(description.count > 20)
            #expect(suggestion.count > 10)
            
            // Should mention API key
            #expect(description.lowercased().contains("api key"))
        }
    }
}