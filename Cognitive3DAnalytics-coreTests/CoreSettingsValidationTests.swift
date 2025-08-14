//
//  CoreSettingsValidationTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
@testable import Cognitive3DAnalytics

@MainActor
struct CoreSettingsValidationTests {
    
    // MARK: - Helper Methods
    
    private func createValidCoreSettings() -> CoreSettings {
        let sceneData = SceneData(
            sceneName: "TestScene",
            sceneId: "550e8400-e29b-41d4-a716-446655440000",
            versionNumber: 1,
            versionId: 123
        )
        
        return CoreSettings(
            defaultSceneName: "TestScene",
            allSceneData: [sceneData],
            apiKey: "valid-api-key-12345",
            loggingLevel: .warningsAndErrors,
            isDebugVerbose: false,
            hmdType: "Vision Pro",
            gazeBatchSize: 32,
            customEventBatchSize: 32,
            sensorDataLimit: 32,
            dynamicDataLimit: 32,
            gazeInterval: 0.1,
            dynamicObjectFileType: gltfFileType,
            fixationBatchSize: 32,
            isOfflineSupportEnabled: true,
            sensorAutoSendInterval: 2.0
        )
    }
    
    // MARK: - Valid Configuration Tests
    
    @Test("Valid configuration passes validation")
    func testValidConfiguration() throws {
        let settings = createValidCoreSettings()
        
        // Should not throw
        try settings.validate()
        
        // Convenience methods should return expected results
        #expect(settings.isValid() == true)
        #expect(settings.getValidationIssues().isEmpty)
    }
    
    // MARK: - API Key Validation Tests
    
    @Test("Missing API key fails validation")
    func testMissingAPIKey() throws {
        let settings = createValidCoreSettings()
        settings.apiKey = ""
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for missing API key")
        } catch let error as Cognitive3DConfigurationError {
            #expect(error == .missingAPIKey)
        }
        
        #expect(settings.isValid() == false)
        let issues = settings.getValidationIssues()
        #expect(!issues.isEmpty)
        #expect(issues.first?.contains("API key is required") == true)
    }
    
    @Test("Short API key fails validation")
    func testShortAPIKey() throws {
        let settings = createValidCoreSettings()
        settings.apiKey = "short"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for short API key")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidAPIKey(let reason) = error {
                #expect(reason.contains("10 characters"))
            } else {
                Issue.record("Expected invalidAPIKey error")
            }
        }
    }
    
    @Test("API key with spaces fails validation")
    func testAPIKeyWithSpaces() throws {
        let settings = createValidCoreSettings()
        settings.apiKey = "api key with spaces"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for API key with spaces")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidAPIKey(let reason) = error {
                #expect(reason.contains("spaces"))
            } else {
                Issue.record("Expected invalidAPIKey error")
            }
        }
    }
    
    @Test("Placeholder API key fails validation")
    func testPlaceholderAPIKey() throws {
        let settings = createValidCoreSettings()
        settings.apiKey = "your-api-key-here"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for placeholder API key")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidAPIKey(let reason) = error {
                #expect(reason.contains("placeholder"))
            } else {
                Issue.record("Expected invalidAPIKey error")
            }
        }
    }
    
    // MARK: - Scene Data Validation Tests
    
    @Test("Missing scene data fails validation")
    func testMissingSceneData() throws {
        let settings = createValidCoreSettings()
        settings.allSceneData = []
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for missing scene data")
        } catch let error as Cognitive3DConfigurationError {
            #expect(error == .missingSceneData)
        }
    }
    
    @Test("Empty default scene name fails validation")
    func testEmptyDefaultSceneName() throws {
        let settings = createValidCoreSettings()
        settings.defaultSceneName = ""
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for empty default scene name")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidSceneName(let name) = error {
                #expect(name.contains("empty"))
            } else {
                Issue.record("Expected invalidSceneName error")
            }
        }
    }
    
    @Test("Default scene not in scene data fails validation")
    func testDefaultSceneNotInData() throws {
        let settings = createValidCoreSettings()
        settings.defaultSceneName = "NonExistentScene"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail when default scene not in scene data")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidSceneName(let message) = error {
                #expect(message.contains("not found"))
                #expect(message.contains("TestScene")) // Should list available scenes
            } else {
                Issue.record("Expected invalidSceneName error")
            }
        }
    }
    
    @Test("Invalid scene ID format fails validation")
    func testInvalidSceneIDFormat() throws {
        let settings = createValidCoreSettings()
        settings.allSceneData[0].sceneId = "invalid-scene-id"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid scene ID format")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidSceneId(let message) = error {
                #expect(message.contains("UUID format"))
            } else {
                Issue.record("Expected invalidSceneId error")
            }
        }
    }
    
    @Test("Scene name too long fails validation")
    func testSceneNameTooLong() throws {
        let settings = createValidCoreSettings()
        settings.allSceneData[0].sceneName = String(repeating: "a", count: 101)
        settings.defaultSceneName = settings.allSceneData[0].sceneName
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for scene name too long")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidSceneName(let message) = error {
                #expect(message.contains("100 character limit"))
            } else {
                Issue.record("Expected invalidSceneName error")
            }
        }
    }
    
    @Test("Invalid scene version fails validation")
    func testInvalidSceneVersion() throws {
        let settings = createValidCoreSettings()
        settings.allSceneData[0].versionNumber = 0
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid scene version")
        } catch let error as Cognitive3DConfigurationError {
            #expect(error == .missingSceneVersion)
        }
    }
    
    // MARK: - Batch Size Validation Tests
    
    @Test("Invalid gaze batch size fails validation")
    func testInvalidGazeBatchSize() throws {
        let settings = createValidCoreSettings()
        settings.gazeBatchSize = 0
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid gaze batch size")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidBatchSize(let parameter, let value, let range) = error {
                #expect(parameter == "gazeBatchSize")
                #expect(value == 0)
                #expect(range == 1...1000)
            } else {
                Issue.record("Expected invalidBatchSize error")
            }
        }
    }
    
    @Test("Batch size too large fails validation")
    func testBatchSizeTooLarge() throws {
        let settings = createValidCoreSettings()
        settings.customEventBatchSize = 2000
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for batch size too large")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidBatchSize(let parameter, let value, _) = error {
                #expect(parameter == "customEventBatchSize")
                #expect(value == 2000)
            } else {
                Issue.record("Expected invalidBatchSize error")
            }
        }
    }
    
    // MARK: - Interval Validation Tests
    
    @Test("Invalid gaze interval fails validation")
    func testInvalidGazeInterval() throws {
        let settings = createValidCoreSettings()
        settings.gazeInterval = 0.0 // Too small
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid gaze interval")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidInterval(let parameter, let value, let range) = error {
                #expect(parameter == "gazeInterval")
                #expect(value == 0.0)
                #expect(range == 0.01...30.0)
            } else {
                Issue.record("Expected invalidInterval error")
            }
        }
    }
    
    @Test("Sensor interval too large fails validation")
    func testSensorIntervalTooLarge() throws {
        let settings = createValidCoreSettings()
        settings.sensorAutoSendInterval = 5000.0 // Too large
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for sensor interval too large")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidInterval(let parameter, let value, _) = error {
                #expect(parameter == "sensorAutoSendInterval")
                #expect(value == 5000.0)
            } else {
                Issue.record("Expected invalidInterval error")
            }
        }
    }
    
    // MARK: - Network Settings Validation Tests
    
    @Test("Invalid HMD type fails validation")
    func testInvalidHMDType() throws {
        let settings = createValidCoreSettings()
        settings.hmdType = "Invalid HMD"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid HMD type")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidConfiguration(let reason) = error {
                #expect(reason.contains("Invalid HMD type"))
            } else {
                Issue.record("Expected invalidConfiguration error")
            }
        }
    }
    
    @Test("Invalid dynamic object file type fails validation")
    func testInvalidDynamicObjectFileType() throws {
        let settings = createValidCoreSettings()
        settings.dynamicObjectFileType = "invalid"
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for invalid dynamic object file type")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidConfiguration(let reason) = error {
                #expect(reason.contains("gltf"))
            } else {
                Issue.record("Expected invalidConfiguration error")
            }
        }
    }
    
    @Test("Network log max records out of range fails validation")
    func testNetworkLogMaxRecordsOutOfRange() throws {
        let settings = createValidCoreSettings()
        settings.networkLogMaxRecords = 20000 // Too large
        
        do {
            try settings.validate()
            Issue.record("Expected validation to fail for network log max records out of range")
        } catch let error as Cognitive3DConfigurationError {
            if case .invalidBatchSize(let parameter, let value, let range) = error {
                #expect(parameter == "networkLogMaxRecords")
                #expect(value == 20000)
                #expect(range == 1...10000)
            } else {
                Issue.record("Expected invalidBatchSize error")
            }
        }
    }
    
    // MARK: - Multiple Error Handling Tests
    
    @Test("Multiple validation errors are collected")
    func testMultipleValidationErrors() throws {
        let settings = createValidCoreSettings()
        settings.apiKey = "" // Error 1
        settings.gazeBatchSize = 0 // Error 2
        settings.gazeInterval = 0.0 // Error 3
        
        let issues = settings.getValidationIssues()
        #expect(issues.count >= 3) // Should have at least 3 issues
        
        let issueText = issues.joined(separator: " ")
        #expect(issueText.contains("API key"))
        #expect(issueText.contains("gazeBatchSize"))
        #expect(issueText.contains("gazeInterval"))
    }
    
    // MARK: - Edge Cases
    
    @Test("Empty HMD type is valid")
    func testEmptyHMDTypeIsValid() throws {
        let settings = createValidCoreSettings()
        settings.hmdType = "" // Should be valid (auto-detection)
        
        // Should not throw
        try settings.validate()
        #expect(settings.isValid() == true)
    }
    
    @Test("Boundary values are valid")
    func testBoundaryValues() throws {
        let settings = createValidCoreSettings()
        
        // Test minimum boundary values
        settings.gazeBatchSize = 1
        settings.gazeInterval = 0.01
        settings.sensorAutoSendInterval = 0.1
        settings.networkLogMaxRecords = 1
        
        try settings.validate()
        #expect(settings.isValid() == true)
        
        // Test maximum boundary values
        settings.gazeBatchSize = 1000
        settings.gazeInterval = 30.0
        settings.sensorAutoSendInterval = 3600.0
        settings.networkLogMaxRecords = 10000
        
        try settings.validate()
        #expect(settings.isValid() == true)
    }
    
    @Test("Valid UUID formats are accepted")
    func testValidUUIDFormats() throws {
        let validUUIDs = [
            "550e8400-e29b-41d4-a716-446655440000",
            "12345678-1234-1234-1234-123456789012",
            "ABCDEF00-1234-5678-9ABC-DEF012345678",
            "abcdef00-1234-5678-9abc-def012345678"
        ]
        
        for uuid in validUUIDs {
            let settings = createValidCoreSettings()
            settings.allSceneData[0].sceneId = uuid
            
            try settings.validate()
            #expect(settings.isValid() == true)
        }
    }
}