//
//  Cognitive3DBuilder.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Builder class for simplified Cognitive3D SDK configuration
/// Provides a fluent API that dramatically reduces configuration complexity while maintaining all functionality
public class Cognitive3DBuilder {
    
    // MARK: - Private Properties
    
    private var apiKey: String = ""
    private var sceneName: String = ""
    private var sceneId: String = ""
    private var sceneVersion: Int = 1
    private var sceneVersionId: Int = 0
    private var additionalScenes: [SceneData] = []
    
    // Advanced settings with sensible defaults
    private var loggingLevel: LogLevel = .warningsAndErrors
    private var isDebugVerbose: Bool = false
    private var coordinateSystem: CoordinateSystem = .leftHanded
    private var batchSizes: BatchSizeConfig = .default
    private var featureToggles: FeatureToggleConfig = .default
    private var networkConfig: NetworkConfig = .default
    
    // Internal state management
    private static var configurationInProgress = false
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Required Configuration
    
    /// Set the API key for authentication with Cognitive3D backend
    /// - Parameter key: Your API key from the Cognitive3D dashboard
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func apiKey(_ key: String) -> Self {
        self.apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return self
    }
    
    /// Configure the primary scene for analytics tracking
    /// - Parameters:
    ///   - name: Human-readable scene name (must match uploaded scene)
    ///   - id: Scene UUID from Cognitive3D platform
    ///   - version: Scene version number (default: 1)
    ///   - versionId: Platform-assigned version ID (default: 0)
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func scene(name: String, id: String, version: Int = 1, versionId: Int = 0) -> Self {
        self.sceneName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sceneId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sceneVersion = version
        self.sceneVersionId = versionId
        return self
    }
    
    // MARK: - Optional Configuration
    
    /// Add additional scenes beyond the primary scene
    /// - Parameter sceneData: Additional scene configuration
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func addScene(_ sceneData: SceneData) -> Self {
        additionalScenes.append(sceneData)
        return self
    }
    
    /// Add additional scene with parameters
    /// - Parameters:
    ///   - name: Scene name
    ///   - id: Scene ID
    ///   - version: Version number
    ///   - versionId: Version ID
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func addScene(name: String, id: String, version: Int = 1, versionId: Int = 0) -> Self {
        let sceneData = SceneData(
            sceneName: name,
            sceneId: id,
            versionNumber: version,
            versionId: versionId
        )
        return addScene(sceneData)
    }
    
    /// Configure logging behavior
    /// - Parameters:
    ///   - level: Logging level (default: warnings and errors only)
    ///   - verbose: Enable verbose debug output (default: false)
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func logging(level: LogLevel = .warningsAndErrors, verbose: Bool = false) -> Self {
        self.loggingLevel = level
        self.isDebugVerbose = verbose
        return self
    }
    
    /// Configure coordinate system for position data
    /// - Parameter system: Coordinate system (.leftHanded for Unity compatibility, .rightHanded for native)
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func coordinateSystem(_ system: CoordinateSystem) -> Self {
        self.coordinateSystem = system
        return self
    }
    
    /// Configure batch sizes and timing for performance optimization
    /// - Parameter config: Batch configuration preset or custom configuration
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func batchSizes(_ config: BatchSizeConfig) -> Self {
        self.batchSizes = config
        return self
    }
    
    /// Configure feature toggles for sensors and tracking
    /// - Parameter config: Feature configuration preset or custom configuration
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func features(_ config: FeatureToggleConfig) -> Self {
        self.featureToggles = config
        return self
    }
    
    /// Configure network behavior and offline support
    /// - Parameter config: Network configuration preset or custom configuration
    /// - Returns: Builder instance for method chaining
    @discardableResult
    public func network(_ config: NetworkConfig) -> Self {
        self.networkConfig = config
        return self
    }
    
    // MARK: - Build and Configure
    
    /// Build configuration and initialize the Cognitive3D SDK
    /// - Throws: Configuration errors if validation fails
    public func configure() async throws {
        guard !Self.configurationInProgress else {
            throw Cognitive3DConfigurationError.configurationInProgress
        }
        
        guard !Cognitive3DAnalyticsCore.shared.isConfigured else {
            throw Cognitive3DConfigurationError.alreadyConfigured
        }
        
        Self.configurationInProgress = true
        defer { Self.configurationInProgress = false }
        
        try validateConfiguration()
        
        let allScenes = buildSceneList()
        let coreSettings = buildCoreSettings(with: allScenes)
        
        // Validate the built configuration before attempting to configure
        try coreSettings.validate()
        
        do {
            try await Cognitive3DAnalyticsCore.shared.configure(with: coreSettings)
            configureAdvancedSettings()
        } catch {
            throw error
        }
    }
    
    // MARK: - Validation
    
    /// Validate configuration without actually configuring the SDK
    /// - Throws: Configuration errors if validation fails
    public func validate() throws {
        try validateConfiguration()
    }
    
    // MARK: - Private Implementation
    
    private func validateConfiguration() throws {
        // Validate API key
        guard !apiKey.isEmpty else {
            throw Cognitive3DConfigurationError.missingAPIKey
        }
        
        guard apiKey.count >= 10 else {
            throw Cognitive3DConfigurationError.invalidAPIKey(reason: "API key is too short")
        }
        
        // Validate scene data
        guard !sceneName.isEmpty else {
            throw Cognitive3DConfigurationError.missingSceneData
        }
        
        guard !sceneId.isEmpty else {
            throw Cognitive3DConfigurationError.missingSceneData
        }
        
        guard sceneName.count > 1 else {
            throw Cognitive3DConfigurationError.invalidSceneName(sceneName)
        }
        
        guard sceneId.count > 10 else {
            throw Cognitive3DConfigurationError.invalidSceneId(sceneId)
        }
        
        // Validate batch sizes
        let batchRange = 1...1000
        
        guard batchRange.contains(batchSizes.gazeBatchSize) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "gazeBatchSize",
                value: batchSizes.gazeBatchSize,
                validRange: batchRange
            )
        }
        
        guard batchRange.contains(batchSizes.customEventBatchSize) else {
            throw Cognitive3DConfigurationError.invalidBatchSize(
                parameter: "customEventBatchSize",
                value: batchSizes.customEventBatchSize,
                validRange: batchRange
            )
        }
        
        // Validate intervals
        let intervalRange = 0.01...30.0
        
        guard intervalRange.contains(batchSizes.gazeInterval) else {
            throw Cognitive3DConfigurationError.invalidInterval(
                parameter: "gazeInterval",
                value: batchSizes.gazeInterval,
                validRange: intervalRange
            )
        }
        
        guard (0.1...3600.0).contains(batchSizes.sensorAutoSendInterval) else {
            throw Cognitive3DConfigurationError.invalidInterval(
                parameter: "sensorAutoSendInterval",
                value: batchSizes.sensorAutoSendInterval,
                validRange: 0.1...3600.0
            )
        }
    }
    
    private func buildSceneList() -> [SceneData] {
        let primaryScene = SceneData(
            sceneName: sceneName,
            sceneId: sceneId,
            versionNumber: sceneVersion,
            versionId: sceneVersionId
        )
        return [primaryScene] + additionalScenes
    }
    
    private func buildCoreSettings(with scenes: [SceneData]) -> CoreSettings {
        return CoreSettings(
            defaultSceneName: sceneName,
            allSceneData: scenes,
            apiKey: apiKey,
            loggingLevel: loggingLevel,
            isDebugVerbose: isDebugVerbose,
            hmdType: visonProHmdType,
            gazeBatchSize: batchSizes.gazeBatchSize,
            customEventBatchSize: batchSizes.customEventBatchSize,
            sensorDataLimit: batchSizes.sensorDataLimit,
            dynamicDataLimit: batchSizes.dynamicDataLimit,
            gazeInterval: batchSizes.gazeInterval,
            dynamicObjectFileType: gltfFileType,
            fixationBatchSize: batchSizes.fixationBatchSize,
            isOfflineSupportEnabled: networkConfig.isOfflineSupportEnabled,
            sensorAutoSendInterval: batchSizes.sensorAutoSendInterval
        )
    }
    
    private func configureAdvancedSettings() {
        let core = Cognitive3DAnalyticsCore.shared
        
        // Apply coordinate system
        core.config?.targetCoordinateSystem = coordinateSystem
        
        // Apply feature toggles
        core.config?.isRecordingFPS = featureToggles.recordFPS
        core.config?.isRecordingPitch = featureToggles.recordPitch
        core.config?.isRecordingYaw = featureToggles.recordYaw
        core.config?.isRecordingBatteryLevel = featureToggles.recordBatteryLevel
        core.config?.shouldEndSessionOnIdle = featureToggles.endSessionOnIdle
        core.config?.shouldSendDataOnInactive = featureToggles.sendDataOnInactive
        core.config?.shouldEndSessionOnBackground = featureToggles.endSessionOnBackground
        core.config?.useSyncServices = featureToggles.useSyncServices
        core.config?.isHandTrackingRequired = featureToggles.handTrackingRequired
        
        // Apply idle threshold if idle detection is enabled
        if featureToggles.endSessionOnIdle {
            core.config?.idleThreshold = featureToggles.idleThreshold
        }
        
        // Apply network logging configuration
        if let networkClient = core.networkClient {
            networkClient.isLoggingEnabled = networkConfig.isNetworkLoggingEnabled
            networkClient.maxLogRecords = networkConfig.networkLogMaxRecords
            networkClient.isVerboseLogging = networkConfig.isNetworkLoggingVerbose
        }
    }
}