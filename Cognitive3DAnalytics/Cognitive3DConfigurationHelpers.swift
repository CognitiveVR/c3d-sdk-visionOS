//
//  Cognitive3DConfigurationHelpers.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// MARK: - Configuration Helper Structures

/// Configuration for batch sizes and timing intervals
public struct BatchSizeConfig {
    public let gazeBatchSize: Int
    public let customEventBatchSize: Int
    public let fixationBatchSize: Int
    public let sensorDataLimit: Int
    public let dynamicDataLimit: Int
    public let gazeInterval: Double
    public let sensorAutoSendInterval: Double
    
    public init(
        gazeBatchSize: Int,
        customEventBatchSize: Int,
        fixationBatchSize: Int,
        sensorDataLimit: Int,
        dynamicDataLimit: Int,
        gazeInterval: Double,
        sensorAutoSendInterval: Double
    ) {
        self.gazeBatchSize = gazeBatchSize
        self.customEventBatchSize = customEventBatchSize
        self.fixationBatchSize = fixationBatchSize
        self.sensorDataLimit = sensorDataLimit
        self.dynamicDataLimit = dynamicDataLimit
        self.gazeInterval = gazeInterval
        self.sensorAutoSendInterval = sensorAutoSendInterval
    }
    
    /// Default batch configuration optimized for most use cases
    public static let `default` = BatchSizeConfig(
        gazeBatchSize: 32,
        customEventBatchSize: 32,
        fixationBatchSize: 32,
        sensorDataLimit: 32,
        dynamicDataLimit: 32,
        gazeInterval: 0.1,
        sensorAutoSendInterval: 2.0
    )
    
    /// Performance configuration with larger batches and higher frequency
    public static let performance = BatchSizeConfig(
        gazeBatchSize: 64,
        customEventBatchSize: 64,
        fixationBatchSize: 64,
        sensorDataLimit: 64,
        dynamicDataLimit: 64,
        gazeInterval: 0.05,
        sensorAutoSendInterval: 1.0
    )
    
    /// Conservative configuration for battery/bandwidth constrained scenarios
    public static let conservative = BatchSizeConfig(
        gazeBatchSize: 16,
        customEventBatchSize: 16,
        fixationBatchSize: 16,
        sensorDataLimit: 16,
        dynamicDataLimit: 16,
        gazeInterval: 0.2,
        sensorAutoSendInterval: 5.0
    )
}

/// Configuration for feature toggles and sensor recording
public struct FeatureToggleConfig {
    public let recordFPS: Bool
    public let recordPitch: Bool
    public let recordYaw: Bool
    public let recordBatteryLevel: Bool
    public let endSessionOnIdle: Bool
    public let idleThreshold: TimeInterval
    public let sendDataOnInactive: Bool
    public let endSessionOnBackground: Bool
    public let useSyncServices: Bool
    public let handTrackingRequired: Bool
    
    public init(
        recordFPS: Bool = true,
        recordPitch: Bool = true,
        recordYaw: Bool = false,
        recordBatteryLevel: Bool = true,
        endSessionOnIdle: Bool = false,
        idleThreshold: TimeInterval = 10.0,
        sendDataOnInactive: Bool = true,
        endSessionOnBackground: Bool = false,
        useSyncServices: Bool = false,
        handTrackingRequired: Bool = false
    ) {
        self.recordFPS = recordFPS
        self.recordPitch = recordPitch
        self.recordYaw = recordYaw
        self.recordBatteryLevel = recordBatteryLevel
        self.endSessionOnIdle = endSessionOnIdle
        self.idleThreshold = idleThreshold
        self.sendDataOnInactive = sendDataOnInactive
        self.endSessionOnBackground = endSessionOnBackground
        self.useSyncServices = useSyncServices
        self.handTrackingRequired = handTrackingRequired
    }
    
    /// Default feature configuration for most applications
    public static let `default` = FeatureToggleConfig()
    
    /// Minimal feature set for apps with performance constraints
    public static let minimal = FeatureToggleConfig(
        recordFPS: false,
        recordPitch: false,
        recordYaw: false,
        recordBatteryLevel: false,
        endSessionOnIdle: false,
        sendDataOnInactive: true,
        endSessionOnBackground: false,
        useSyncServices: false,
        handTrackingRequired: false
    )
    
    /// Comprehensive feature set for detailed analytics
    public static let comprehensive = FeatureToggleConfig(
        recordFPS: true,
        recordPitch: true,
        recordYaw: true,
        recordBatteryLevel: true,
        endSessionOnIdle: true,
        idleThreshold: 30.0,
        sendDataOnInactive: true,
        endSessionOnBackground: true,
        useSyncServices: true,
        handTrackingRequired: true
    )
}

/// Configuration for network behavior and offline support
public struct NetworkConfig {
    public let isOfflineSupportEnabled: Bool
    public let isNetworkLoggingEnabled: Bool
    public let networkLogMaxRecords: Int
    public let isNetworkLoggingVerbose: Bool
    
    public init(
        isOfflineSupportEnabled: Bool = true,
        isNetworkLoggingEnabled: Bool = false,
        networkLogMaxRecords: Int = 100,
        isNetworkLoggingVerbose: Bool = false
    ) {
        self.isOfflineSupportEnabled = isOfflineSupportEnabled
        self.isNetworkLoggingEnabled = isNetworkLoggingEnabled
        self.networkLogMaxRecords = networkLogMaxRecords
        self.isNetworkLoggingVerbose = isNetworkLoggingVerbose
    }
    
    /// Default network configuration
    public static let `default` = NetworkConfig()
    
    /// Debug configuration with verbose network logging
    public static let debug = NetworkConfig(
        isOfflineSupportEnabled: true,
        isNetworkLoggingEnabled: true,
        networkLogMaxRecords: 500,
        isNetworkLoggingVerbose: true
    )
    
    /// Network-only configuration (disables offline support)
    public static let networkOnly = NetworkConfig(
        isOfflineSupportEnabled: false,
        isNetworkLoggingEnabled: false,
        networkLogMaxRecords: 100,
        isNetworkLoggingVerbose: false
    )
}

// MARK: - Enhanced Error Types

/// Comprehensive error types for configuration validation
public enum Cognitive3DConfigurationError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey(reason: String)
    case missingSceneData
    case invalidSceneName(String)
    case invalidSceneId(String)
    case missingSceneVersion
    case invalidBatchSize(parameter: String, value: Int, validRange: ClosedRange<Int>)
    case invalidInterval(parameter: String, value: Double, validRange: ClosedRange<Double>)
    case invalidCoordinateSystem
    case invalidConfiguration(reason: String)
    case alreadyConfigured
    case configurationInProgress
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is required. Get your API key from the Cognitive3D dashboard."
        case .invalidAPIKey(let reason):
            return "Invalid API key: \(reason). Verify your API key at dashboard.cognitive3d.com"
        case .missingSceneData:
            return "Scene configuration is required. Provide at least one scene with name and ID."
        case .invalidSceneName(let name):
            return "Invalid scene name '\(name)'. Scene names cannot be empty and should match your uploaded scene."
        case .invalidSceneId(let id):
            return "Invalid scene ID '\(id)'. Scene ID should be a valid UUID from the Cognitive3D platform."
        case .missingSceneVersion:
            return "Scene version information is required. Provide version number and version ID."
        case .invalidBatchSize(let parameter, let value, let range):
            return "Invalid \(parameter): \(value). Must be between \(range.lowerBound) and \(range.upperBound)."
        case .invalidInterval(let parameter, let value, let range):
            return "Invalid \(parameter): \(value). Must be between \(range.lowerBound) and \(range.upperBound) seconds."
        case .invalidCoordinateSystem:
            return "Invalid coordinate system. Use .leftHanded for Unity compatibility or .rightHanded for native visionOS."
        case .invalidConfiguration(let reason):
            return "Configuration error: \(reason)"
        case .alreadyConfigured:
            return "Cognitive3D is already configured. Call reset() before reconfiguring."
        case .configurationInProgress:
            return "Configuration is already in progress. Wait for current configuration to complete."
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey, .invalidAPIKey:
            return "Visit https://dashboard.cognitive3d.com to generate a new API key for your application."
        case .missingSceneData, .invalidSceneName, .invalidSceneId:
            return "Upload your scene to the Cognitive3D platform and use the provided scene name and ID."
        case .missingSceneVersion:
            return "Check your scene version information in the Cognitive3D dashboard."
        case .invalidBatchSize, .invalidInterval:
            return "Use BatchSizeConfig.default for recommended settings or consult the documentation for valid ranges."
        case .invalidCoordinateSystem:
            return "Most visionOS apps should use .leftHanded coordinate system for Unity compatibility."
        case .invalidConfiguration:
            return "Check the configuration requirements in the documentation or use the simplified setup methods."
        case .alreadyConfigured:
            return "If you need to reconfigure, call Cognitive3DAnalyticsCore.shared.reset() first."
        case .configurationInProgress:
            return "Wait for the current configuration to complete before attempting to reconfigure."
        }
    }
}