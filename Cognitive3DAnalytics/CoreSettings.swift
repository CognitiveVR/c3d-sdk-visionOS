//
//  CoreSettings.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-12-04.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The `CoreSettings` class contains various settings that are used to configure the C3D SDK at run-time.
// TODO: compare the use of config class & settings class. Can they be combined into one class?
public class CoreSettings {

    /// Metadata for the scene name.
    public var defaultSceneName: String = ""

    public var allSceneData: [SceneData] = []
    
    public var apiKey: String = ""

    public var loggingLevel: LogLevel = .all

    public var isDebugVerbose: Bool = false
    
    public var hmdType: String = ""

    public var gazeBatchSize: Int = 32

    public var customEventBatchSize: Int = 32

    public var sensorDataLimit: Int = 32

    public var dynamicDataLimit: Int = 32

    public var gazeInterval: Double = 0.1

    /// At this time, the SDK works with GLTF files, other file type may be supported in the future.
    public var dynamicObjectFileType: String = gltfFileType

    /// Fixation batch size - currently unused
    public var fixationBatchSize: Int = 32

    /// Set this to true to activate network connectivity monitoring and offline data handling.
    public var isOfflineSupportEnabled: Bool = true

    /// Enable network request logging
    public var isNetworkLoggingEnabled: Bool = false

    /// Maximum number of network request records to keep
    public var networkLogMaxRecords: Int = 100

    /// Enable verbose network logging
    public var isNetworkLoggingVerbose: Bool = false

    public var isHandTrackingRequired = false

    /// Sensor auto-send timer interval in seconds
    public var sensorAutoSendInterval: Double = 2.0

    public init(
        defaultSceneName: String = "",
        allSceneData: [SceneData] = [],
        apiKey: String = "",
        loggingLevel: LogLevel = .all,
        isDebugVerbose: Bool = false,
        hmdType: String = "",
        gazeBatchSize: Int = 32,
        customEventBatchSize: Int = 32,
        sensorDataLimit: Int = 32,
        dynamicDataLimit: Int = 32,
        gazeInterval: Double = 0.1,
        dynamicObjectFileType: String = gltfFileType,
        fixationBatchSize: Int = 32,
        isOfflineSupportEnabled: Bool = true,
        sensorAutoSendInterval: Double = 20.0
    ) {
        self.defaultSceneName = defaultSceneName
        self.allSceneData = allSceneData
        self.apiKey = apiKey
        self.loggingLevel = loggingLevel
        self.isDebugVerbose = isDebugVerbose
        self.hmdType = hmdType
        self.gazeBatchSize = gazeBatchSize
        self.customEventBatchSize = customEventBatchSize
        self.sensorDataLimit = sensorDataLimit
        self.dynamicDataLimit = dynamicDataLimit
        self.gazeInterval = gazeInterval
        self.dynamicObjectFileType = dynamicObjectFileType
        self.fixationBatchSize = fixationBatchSize
        self.isOfflineSupportEnabled = isOfflineSupportEnabled
        self.sensorAutoSendInterval = sensorAutoSendInterval
    }
    
    // MARK: - Validation
    
    /// Validates all configuration parameters and throws specific errors for any issues found
    /// - Throws: `Cognitive3DConfigurationError` for any validation failures
    public func validate() throws {
        try validateAPIKey()
        try validateSceneData()
        try validateBatchSizes()
        try validateIntervals()
        try validateNetworkSettings()
    }
    
    /// Validates the API key format and content
    private func validateAPIKey() throws {
        guard !apiKey.isEmpty else {
            throw Cognitive3DConfigurationError.missingAPIKey
        }
        
        guard apiKey.count >= 10 else {
            throw Cognitive3DConfigurationError.invalidAPIKey(
                reason: "API key must be at least 10 characters long"
            )
        }
        
        guard !apiKey.contains(" ") else {
            throw Cognitive3DConfigurationError.invalidAPIKey(
                reason: "API key cannot contain spaces"
            )
        }
        
        // Check for common test/placeholder values
        let invalidPatterns = ["test", "demo", "placeholder", "your-api-key", "xxx", "000"]
        let lowercaseKey = apiKey.lowercased()
        for pattern in invalidPatterns {
            if lowercaseKey.contains(pattern) {
                throw Cognitive3DConfigurationError.invalidAPIKey(
                    reason: "API key appears to be a placeholder value. Use your actual API key from dashboard.cognitive3d.com"
                )
            }
        }
    }
    
    /// Validates scene configuration
    private func validateSceneData() throws {
        guard !allSceneData.isEmpty else {
            throw Cognitive3DConfigurationError.missingSceneData
        }
        
        guard !defaultSceneName.isEmpty else {
            throw Cognitive3DConfigurationError.invalidSceneName("Default scene name cannot be empty")
        }
        
        // Validate each scene in the collection
        for (index, scene) in allSceneData.enumerated() {
            try validateScene(scene, at: index)
        }
        
        // Ensure default scene exists in the scene data
        let hasDefaultScene = allSceneData.contains { $0.sceneName == defaultSceneName }
        guard hasDefaultScene else {
            throw Cognitive3DConfigurationError.invalidSceneName(
                "Default scene '\(defaultSceneName)' not found in scene data. Available scenes: \(allSceneData.map { $0.sceneName }.joined(separator: ", "))"
            )
        }
    }
    
    /// Validates an individual scene
    private func validateScene(_ scene: SceneData, at index: Int) throws {
        // Scene name validation
        guard !scene.sceneName.isEmpty else {
            throw Cognitive3DConfigurationError.invalidSceneName(
                "Scene name at index \(index) cannot be empty"
            )
        }
        
        guard scene.sceneName.count <= 100 else {
            throw Cognitive3DConfigurationError.invalidSceneName(
                "Scene name '\(scene.sceneName)' exceeds 100 character limit"
            )
        }
        
        // Scene ID validation - should be a valid UUID format
        guard !scene.sceneId.isEmpty else {
            throw Cognitive3DConfigurationError.invalidSceneId(
                "Scene ID for '\(scene.sceneName)' cannot be empty"
            )
        }
        
        // Basic UUID format check (36 characters with hyphens in correct positions)
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        let uuidRegex = try! NSRegularExpression(pattern: uuidPattern)
        let range = NSRange(location: 0, length: scene.sceneId.utf16.count)
        
        guard uuidRegex.firstMatch(in: scene.sceneId, options: [], range: range) != nil else {
            throw Cognitive3DConfigurationError.invalidSceneId(
                "Scene ID '\(scene.sceneId)' for scene '\(scene.sceneName)' is not a valid UUID format. Expected format: 12345678-1234-1234-1234-123456789012"
            )
        }
        
        // Version validation
        guard scene.versionNumber >= 1 else {
            throw Cognitive3DConfigurationError.missingSceneVersion
        }
        
        guard scene.versionId >= 0 else {
            throw Cognitive3DConfigurationError.missingSceneVersion
        }
    }
    
    /// Validates batch size parameters
    private func validateBatchSizes() throws {
        let validBatchRange = 1...1000
        
        guard validBatchRange.contains(gazeBatchSize) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "gazeBatchSize",
                value: gazeBatchSize,
                validRange: validBatchRange
            )
        }
        
        guard validBatchRange.contains(customEventBatchSize) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "customEventBatchSize",
                value: customEventBatchSize,
                validRange: validBatchRange
            )
        }
        
        guard validBatchRange.contains(sensorDataLimit) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "sensorDataLimit",
                value: sensorDataLimit,
                validRange: validBatchRange
            )
        }
        
        guard validBatchRange.contains(dynamicDataLimit) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "dynamicDataLimit",
                value: dynamicDataLimit,
                validRange: validBatchRange
            )
        }
        
        guard validBatchRange.contains(fixationBatchSize) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "fixationBatchSize",
                value: fixationBatchSize,
                validRange: validBatchRange
            )
        }
    }
    
    /// Validates timing interval parameters
    private func validateIntervals() throws {
        // Gaze interval validation (10ms to 30 seconds)
        let gazeIntervalRange = 0.01...30.0
        guard gazeIntervalRange.contains(gazeInterval) else {
            throw Cognitive3DConfigurationError.invalidInterval(
                parameter: "gazeInterval",
                value: gazeInterval,
                validRange: gazeIntervalRange
            )
        }
        
        // Sensor auto-send interval validation (100ms to 1 hour)
        let sensorIntervalRange = 0.1...3600.0
        guard sensorIntervalRange.contains(sensorAutoSendInterval) else {
            throw Cognitive3DConfigurationError.invalidInterval(
                parameter: "sensorAutoSendInterval",
                value: sensorAutoSendInterval,
                validRange: sensorIntervalRange
            )
        }
    }
    
    /// Validates network-related settings
    private func validateNetworkSettings() throws {
        // Network log records validation
        guard networkLogMaxRecords > 0 && networkLogMaxRecords <= 10000 else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "networkLogMaxRecords",
                value: networkLogMaxRecords,
                validRange: 1...10000
            )
        }
        
        // HMD type validation (if provided)
        if !hmdType.isEmpty {
            let validHmdTypes = ["Vision Pro", visonProHmdType]
            guard validHmdTypes.contains(hmdType) else {
                throw Cognitive3DConfigurationError.invalidConfiguration(
                    reason: "Invalid HMD type '\(hmdType)'. For visionOS, use 'Vision Pro' or leave empty for auto-detection"
                )
            }
        }
        
        // Dynamic object file type validation
        guard dynamicObjectFileType == gltfFileType else {
            throw Cognitive3DConfigurationError.invalidConfiguration(
                reason: "Invalid dynamic object file type '\(dynamicObjectFileType)'. Currently only 'gltf' is supported"
            )
        }
    }
    
    /// Performs a quick validation check without throwing errors
    /// - Returns: `true` if all settings are valid, `false` otherwise
    public func isValid() -> Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }
    
    /// Gets a list of validation issues without throwing errors
    /// - Returns: Array of validation error descriptions
    public func getValidationIssues() -> [String] {
        var issues: [String] = []
        
        do {
            try validateAPIKey()
        } catch {
            issues.append(error.localizedDescription)
        }
        
        do {
            try validateSceneData()
        } catch {
            issues.append(error.localizedDescription)
        }
        
        do {
            try validateBatchSizes()
        } catch {
            issues.append(error.localizedDescription)
        }
        
        do {
            try validateIntervals()
        } catch {
            issues.append(error.localizedDescription)
        }
        
        do {
            try validateNetworkSettings()
        } catch {
            issues.append(error.localizedDescription)
        }
        
        return issues
    }
}
