//
//  SetupValidatorTests.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
@testable import Cognitive3DAnalytics

@MainActor
struct SetupValidatorTests {
    
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
    
    private func createInvalidCoreSettings() -> CoreSettings {
        return CoreSettings(
            defaultSceneName: "",
            allSceneData: [],
            apiKey: "",
            loggingLevel: .all,
            isDebugVerbose: false,
            hmdType: "",
            gazeBatchSize: 0,
            customEventBatchSize: 0,
            sensorDataLimit: 0,
            dynamicDataLimit: 0,
            gazeInterval: -1.0,
            dynamicObjectFileType: gltfFileType,
            fixationBatchSize: 0,
            isOfflineSupportEnabled: true,
            sensorAutoSendInterval: -1.0
        )
    }
    
    // MARK: - Basic Validation Tests
    
    @Test("Valid configuration passes comprehensive validation")
    func testValidConfigurationPasses() throws {
        let settings = createValidCoreSettings()
        let result = Cognitive3DSetupValidator.validateConfiguration(settings)
        
        // Should have no error-level issues
        let errors = result.issues(withSeverity: .error)
        #expect(errors.isEmpty, "Valid configuration should not have errors")
        
        // Result should be valid
        #expect(result.isValid, "Valid configuration should pass validation")
    }
    
    @Test("Invalid configuration fails comprehensive validation")
    func testInvalidConfigurationFails() throws {
        let settings = createInvalidCoreSettings()
        let result = Cognitive3DSetupValidator.validateConfiguration(settings)
        
        // Should have error-level issues
        let errors = result.issues(withSeverity: .error)
        #expect(!errors.isEmpty, "Invalid configuration should have errors")
        
        // Result should not be valid
        #expect(!result.isValid, "Invalid configuration should fail validation")
    }
    
    @Test("Basic setup validation returns correct boolean")
    func testBasicSetupValidation() throws {
        let validSettings = createValidCoreSettings()
        let invalidSettings = createInvalidCoreSettings()
        
        #expect(Cognitive3DSetupValidator.isBasicSetupValid(validSettings))
        #expect(!Cognitive3DSetupValidator.isBasicSetupValid(invalidSettings))
    }
    
    // MARK: - Validation Result Tests
    
    @Test("Validation result properties work correctly")
    func testValidationResultProperties() throws {
        let settings = createValidCoreSettings()
        let result = Cognitive3DSetupValidator.validateConfiguration(settings)
        
        // Test timestamp
        #expect(result.timestamp.timeIntervalSinceNow < 1.0, "Timestamp should be recent")
        
        // Test severity filtering
        let allIssues = result.issues
        let errors = result.issues(withSeverity: .error)
        let warnings = result.issues(withSeverity: .warning)
        let infos = result.issues(withSeverity: .info)
        
        #expect(allIssues.count == errors.count + warnings.count + infos.count)
        
        // Test category filtering
        let configIssues = result.issues(inCategory: .configuration)
        let networkIssues = result.issues(inCategory: .network)
        let deviceIssues = result.issues(inCategory: .device)
        let permissionIssues = result.issues(inCategory: .permissions)
        
        #expect(allIssues.count == configIssues.count + networkIssues.count + deviceIssues.count + permissionIssues.count)
    }
    
    @Test("Validation result convenience properties work")
    func testValidationResultConvenienceProperties() throws {
        // Test with invalid settings to ensure we get errors
        let settings = createInvalidCoreSettings()
        let result = Cognitive3DSetupValidator.validateConfiguration(settings)
        
        // Should have errors
        #expect(!result.isValid)
        
        // Check boolean properties based on actual issues
        if !result.issues(withSeverity: .warning).isEmpty {
            #expect(result.hasWarnings)
        }
        
        if !result.issues(withSeverity: .info).isEmpty {
            #expect(result.hasInfo)
        }
    }
    
    // MARK: - Network Validation Tests
    
    @Test("Network connectivity validation returns appropriate result")
    func testNetworkConnectivityValidation() async throws {
        let networkIssue = Cognitive3DSetupValidator.validateNetworkConnectivity()
        
        // Network validation should either return nil (good connection) or a validation issue
        if let issue = networkIssue {
            #expect([.warning, .info, .error].contains(issue.severity))
            #expect(issue.category == .network)
            #expect(!issue.message.isEmpty)
            #expect(!issue.solution.isEmpty)
        }
    }
    
    // MARK: - Report Generation Tests
    
    @Test("Validation report generation works correctly")
    func testReportGeneration() throws {
        let settings = createInvalidCoreSettings()
        let result = Cognitive3DSetupValidator.validateConfiguration(settings)
        
        let report = result.generateReport()
        
        // Report should contain expected elements
        #expect(report.contains("Cognitive3D Setup Validation Report"))
        #expect(report.contains("Generated:"))
        #expect(report.contains("Overall Status:"))
        
        // If there are errors, report should contain error section
        if !result.issues(withSeverity: .error).isEmpty {
            #expect(report.contains("ERRORS"))
        }
        
        // If there are warnings, report should contain warning section  
        if !result.issues(withSeverity: .warning).isEmpty {
            #expect(report.contains("WARNINGS"))
        }
        
        // If there are info messages, report should contain info section
        if !result.issues(withSeverity: .info).isEmpty {
            #expect(report.contains("INFORMATION"))
        }
    }
    
    @Test("Empty validation result generates appropriate report")
    func testEmptyValidationReportGeneration() throws {
        // Create a minimal validation result with no issues
        let emptyResult = ValidationResult(issues: [])
        let report = emptyResult.generateReport()
        
        #expect(report.contains("No issues found"))
        #expect(report.contains("SDK is ready for use"))
    }
    
    // MARK: - Validation Issue Tests
    
    @Test("Validation issue properties work correctly")
    func testValidationIssueProperties() throws {
        let issue = ValidationIssue(
            severity: .error,
            message: "Test error message",
            solution: "Test solution",
            category: .configuration
        )
        
        #expect(issue.severity == .error)
        #expect(issue.message == "Test error message")
        #expect(issue.solution == "Test solution")
        #expect(issue.category == .configuration)
        
        // Test emoji property
        #expect(issue.severity.emoji == "❌")
        
        // Test category display name
        #expect(issue.category.displayName == "Configuration")
    }
    
    @Test("All severity levels have emojis")
    func testSeverityEmojis() throws {
        #expect(ValidationIssue.Severity.error.emoji == "❌")
        #expect(ValidationIssue.Severity.warning.emoji == "⚠️")
        #expect(ValidationIssue.Severity.info.emoji == "ℹ️")
    }
    
    @Test("All categories have display names")
    func testCategoryDisplayNames() throws {
        #expect(ValidationIssue.Category.configuration.displayName == "Configuration")
        #expect(ValidationIssue.Category.network.displayName == "Network")
        #expect(ValidationIssue.Category.permissions.displayName == "Permissions")
        #expect(ValidationIssue.Category.device.displayName == "Device")
    }
    
    // MARK: - Convenience Method Tests
    
    @Test("Quick validation returns error messages")
    func testQuickValidation() throws {
        let invalidSettings = createInvalidCoreSettings()
        let errors = Cognitive3DSetupValidator.quickValidation(invalidSettings)
        
        #expect(!errors.isEmpty, "Invalid configuration should return error messages")
        
        // All returned items should be non-empty strings
        for error in errors {
            #expect(!error.isEmpty)
        }
        
        // Test with valid settings
        let validSettings = createValidCoreSettings()
        let validErrors = Cognitive3DSetupValidator.quickValidation(validSettings)
        
        // Valid settings should have no errors (may have warnings/info but not errors)
        #expect(validErrors.isEmpty, "Valid configuration should return no error messages")
    }
    
    @Test("Validate and print returns correct boolean")
    func testValidateAndPrint() throws {
        let validSettings = createValidCoreSettings()
        let invalidSettings = createInvalidCoreSettings()
        
        // Valid settings should return true
        let validResult = Cognitive3DSetupValidator.validateAndPrint(validSettings)
        #expect(validResult, "Valid settings should return true")
        
        // Invalid settings should return false
        let invalidResult = Cognitive3DSetupValidator.validateAndPrint(invalidSettings)
        #expect(!invalidResult, "Invalid settings should return false")
    }
    
    // MARK: - Integration Tests
    
    @Test("Core Analytics validation methods work correctly")
    func testCoreAnalyticsValidationMethods() throws {
        let validSettings = createValidCoreSettings()
        let invalidSettings = createInvalidCoreSettings()
        
        // Test static validation methods
        let validResult = Cognitive3DAnalyticsCore.validateConfiguration(validSettings)
        let invalidResult = Cognitive3DAnalyticsCore.validateConfiguration(invalidSettings)
        
        #expect(validResult.isValid, "Valid settings should pass Core Analytics validation")
        #expect(!invalidResult.isValid, "Invalid settings should fail Core Analytics validation")
        
        // Test configuration validity check
        #expect(Cognitive3DAnalyticsCore.isConfigurationValid(validSettings))
        #expect(!Cognitive3DAnalyticsCore.isConfigurationValid(invalidSettings))
    }
    
    @Test("Current setup validation returns nil when not configured")
    func testCurrentSetupValidationWhenNotConfigured() throws {
        // Ensure SDK is not configured
        Cognitive3DAnalyticsCore.reset()
        
        let result = Cognitive3DAnalyticsCore.validateCurrentSetup()
        #expect(result == nil, "Should return nil when SDK is not configured")
    }
    
    // MARK: - Edge Cases
    
    @Test("Validation handles edge cases correctly")
    func testValidationEdgeCases() throws {
        // Test with extremely minimal but valid settings
        let minimalSettings = createValidCoreSettings()
        minimalSettings.gazeBatchSize = 1 // Minimum valid
        minimalSettings.gazeInterval = 0.01 // Minimum valid
        
        let result = Cognitive3DSetupValidator.validateConfiguration(minimalSettings)
        
        // Should still be valid
        #expect(result.isValid, "Minimal valid settings should pass validation")
        
        // Test with maximum valid settings
        let maximalSettings = createValidCoreSettings()
        maximalSettings.gazeBatchSize = 1000 // Maximum valid
        maximalSettings.gazeInterval = 30.0 // Maximum valid
        
        let maxResult = Cognitive3DSetupValidator.validateConfiguration(maximalSettings)
        #expect(maxResult.isValid, "Maximal valid settings should pass validation")
    }
}