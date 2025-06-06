//
//  Cognitive3DAnalyticsCore.swift
//  Cognitive3DAnalytics
//
//  Created by Calder Archinuk on 2024-11-18.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Combine
import Foundation
import OSLog
import ObjectiveC
import Observation
import RealityKit
import SwiftUI
/// Need to import this to get the access to the device for the installed app.
import UIKit

/// Represents the state of the current analytics session.
/// Tracks application phases, such as active, paused, or ended (e.g., app enters background).
public enum SessionState {
    /// Initial state of the SDK -ready for action.
    case ready

    /// The application is in the active state and likely being interacted with.
    case activeAppActive

    /// The analytics session is running but the data sources are paused.
    /// The user may switched to interact with another app.
    case pausedAppInActive

    /// The current session has been ended from an idle threshold has been passed.
    case endedIdle(timeInterval: TimeInterval)

    /// The current session has been ended from the application going in to the background.
    case endedBackground
}

@frozen public enum SessionEvent {
    case started(sessionId: String)
    case ended(sessionId: String, state: SessionState)
}

/// Delegate protocol for when analytics session ends.
public protocol SessionDelegate: AnyObject {
    func sessionDidEnd(sessionId: String, sessionState: SessionState)
}

/// Device property types for analytics tracking
public enum DeviceProperty {
    case appName,
        appVersion,
        appEngine,
        appEngineVersion,
        deviceType,
        deviceModel,
        deviceMemory,
        deviceOS,
        deviceCPU,
        deviceCPUCores,
        deviceCPUVendor,
        deviceGPU,
        deviceGPUDriver,
        deviceGPUVendor,
        deviceGPUMemory,
        vrModel,
        vrVendor
}

public enum Cognitive3DError: Error {
    case alreadyConfigured
    case notConfigured
    case invalidConfiguration
}

public protocol IdleSessionDelegate: AnyObject {
    func sessionDidEndDueToIdle(sessionId: String, idleDuration: TimeInterval)
}

/// Cognitive3DAnalyticsCore: this class manages session tracking, device property collection, and interactions
/// with the Cognitive3D backend.
public class Cognitive3DAnalyticsCore {
    // MARK: - Singleton

    /// Shared instance of the analytics core
    public static let shared = Cognitive3DAnalyticsCore()

    /// Tracks whether the SDK is fully initialized.
    /// Ensures methods dependent on configuration are not called prematurely.
    private var isConfigured: Bool = false

    // MARK: - Properties
    internal let arSessionManager = ARSessionManager.shared

    private var currentSceneId: String = ""
    private var currentSceneVersionId: Int = 0
    private var currentSceneVersionNumber: Int = 0
    public var config: Config?
    internal var logger: CognitiveLog?

    private var exitPoll: ExitPollSurvey?

    // MARK: - recorders
    internal(set) public var customEventRecorder: EventRecorder?
    public private(set) var gazeTracker: GazeRecorder?
    public private(set) var sensorRecorder: SensorRecorder?
    private var pitchRecorder: PitchRecorder?
    private var yawRecorder: YawRecorder?
    public private(set) var dynamicDataManager: DynamicDataManager?
    private var frameRateRecorder: FrameRateRecorder?
    private var batteryLevelRecorder: BatteryLevelRecorder?

    // MARK: - session data
    /// Synchronizes gaze tracking with dynamic objects.
    public private(set) var gazeSyncManager = GazeSyncManager()

    private var lobbyId = ""
    private var sessionTimestamp: Double = -1
    public private(set) var sessionId = ""
    /// Configurable session name.
    private var sessionName = ""
    /// Full name for participant; used in sessions.
    private var participantName = ""
    /// Id for participant; used in sessions and exit poll surveys.
    private var participantId = ""
    private var userId = ""
    private var deviceId = ""

    // MARK: - session properties
    // used internally for recording session properties set before the session has initialized
    // TODO: Implement pre-session property tracking.
    // Required for recording properties set before a session initializes.
    internal var preSessionProperties = [String: Any]()

    /// Stores all session properties, including those pending upload.
    /// Mimics the behavior of the C# SDK, where properties are prefixed with 'known'.
    internal var allSessionProperties = [String: Any]()

    // any changed properties that have not been written to the session
    internal var newSessionProperties = [String: Any]()

    public private(set) var isSessionActive: Bool = false

    // MARK: -

    /// Debug control variable
    private var isGazeTrackerStartedOnStart: Bool = true

    internal let defaultPos: [Double] = [0, 0, 0]

    /// The scene is used with the gaze tracker for doing ray casts with dynamic object entities.
    public var entity: Entity?
    /// The scene is used when doing ray casts with dynamic objects.
    // TODO: refactor - ideally, store the scene but it's not known until sometime after a RealityView has rendered.
    public var scene: RealityKit.Scene?

    internal var networkClient: NetworkAPIClient?

    /// Tracks user idle state
    internal var idleDetector: IdleDetector?

    /// Session state
    public var sessionState: SessionState = .ready
    public weak var sessionDelegate: SessionDelegate?

    internal private(set) var dataCacheSystem: DataCacheSystem?
    internal var lastSyncTime: Date?
    internal let minSyncInterval: TimeInterval = 5.0  // 5 seconds between syncs

    private var networkDataCacheDelegate: NetworkDataCacheDelegate?

    public let sessionEventPublisher = PassthroughSubject<SessionEvent, Never>()

    /// Component for esimateing the HMD height
    private var hmdHeight: HmdHeight?

    /// Component for hand tracking if enabled by the user
    private var handTracking: HandTracking?

    // MARK: - Configuration
    public func configure(with settings: CoreSettings) async throws {
        guard !isConfigured else {
            throw Cognitive3DError.alreadyConfigured
        }

        // Step 1: Setup basic logging
        setupLogging(level: settings.loggingLevel, verbose: settings.isDebugVerbose)

        // Step 2: Setup configuration
        setupConfiguration(settings: settings)

        // Step 3: Setup device identifier
        setupDeviceIdentifier()

        // Step 4: Initialize network client
        setupNetworkClient(apiKey: settings.apiKey, isDebugVerbose: settings.isDebugVerbose)

        // Step 5: Setup data cache system
        await setupDataCacheSystem()

        // Step 6: Initialize recorders
        setupRecorders(settings: settings)

        // Step 7: Setup scene data
        setupSceneData(settings: settings)

        // Step 8: Setup network logging
        #if DEBUG && ENABLE_NETWORK_LOGGING
            logger?.info("DEBUG build, network request logging will be activated")
            enableNetworkLogging(enabled: true, maxRecords: 100, isVerboseLogging: settings.isDebugVerbose)
        #endif

        // Step 9: Setup connectivity support if needed
        if settings.isOfflineSupportEnabled {
            await setupConnectivitySupport()
        }

        self.hmdHeight = HmdHeight()

        // Hand tracking works only on a device.
        #if !targetEnvironment(simulator)
            if let config = self.config, config.isHandTrackingRequired {
                HandTracking.setup(core: self)
                Task {
                    await HandTracking.runSession()
                }
            }
        #endif

        isConfigured = true
        logger?.info("Cognitive3DAnalyticsCore configuration completed")
    }

    /// Initializes the logging system for the SDK.
    /// - Parameters:
    ///   - level: The minimum severity level to log (e.g., debug, info, error).
    ///   - verbose: Enables detailed debug messages when true.
    private func setupLogging(level: LogLevel, verbose: Bool) {
        logger = CognitiveLog()
        logger?.setLoggingLevel(level: level)
        logger?.isDebugVerbose = verbose
        print("Cognitive3DAnalyticsCore() version \(Cognitive3DAnalyticsCore.version)")
    }

    private func setupConfiguration(settings: CoreSettings) {
        config = Config()
        config?.hmdType = settings.hmdType
        config?.applicationKey = settings.apiKey
        config?.gazeBatchSize = settings.gazeBatchSize
        config?.customEventBatchSize = settings.customEventBatchSize
        config?.sensorDataLimit = settings.sensorDataLimit
        config?.dynamicDataLimit = settings.dynamicDataLimit
        config?.gazeInterval = Float(settings.gazeInterval)
        config?.dynamicObjectFileType = settings.dynamicObjectFileType
        config?.fixationBatchSize = settings.fixationBatchSize
        config?.isHandTrackingRequired = settings.isHandTrackingRequired
        config?.sensorAutoSendInterval = settings.sensorAutoSendInterval
    }

    private func setupDeviceIdentifier() {
        if let deviceId = UIDevice.current.identifierForVendor?.uuidString {
            let cleanIdentifier = deviceId.lowercased().replacingOccurrences(of: "-", with: "")
            setDeviceName(name: cleanIdentifier)
            userId = cleanIdentifier
        } else {
            setDeviceName(name: "UUID not available")
        }
    }

    private func setupNetworkClient(apiKey: String, isDebugVerbose: Bool) {
        self.networkClient = NetworkAPIClient(apiKey: apiKey, cog: self, isDebugVerbose: isDebugVerbose)
    }

    private func setupDataCacheSystem() async {
        dataCacheSystem = DataCacheSystem()

        if let networkClient = self.networkClient, let dataCacheSystem = self.dataCacheSystem {
            // Store the delegate as a property to retain it
            self.networkDataCacheDelegate = NetworkDataCacheDelegate(networkClient: networkClient)

            // Create and set the delegate within the actor instead of from outside
            await dataCacheSystem.setDelegate(self.networkDataCacheDelegate)

            // Remove immediate cache check during initialization to avoid redundant uploads
            // await dataCacheSystem.uploadCachedContent()

            logger?.verbose("Data cache system configured with network client")
        } else {
            logger?.error("Failed to initialize data cache system with network client")
        }
    }

    // TODO: refactor - this is inefficient as it is creating new recorders.
    private func setupRecorders(settings: CoreSettings) {
        if !settings.defaultSceneName.isEmpty,
            let sceneData = settings.allSceneData.first(where: { $0.sceneName == settings.defaultSceneName })
        {
            if sceneData.sceneId.isEmpty {
                logger?.error("Invalid scene configuration: Empty scene ID for scene \(settings.defaultSceneName)")
                return
            }

            configureSensorRecording(sceneData)
        }

        gazeTracker = GazeRecorder(core: self)
        exitPoll = ExitPollSurvey(core: self)

        dynamicDataManager = DynamicDataManager(core: self)
        if let dynamicManager = dynamicDataManager {
            gazeSyncManager.addDelegate(dynamicManager)
        }
    }

    private func setupSceneData(settings: CoreSettings) {
        config?.allSceneData = settings.allSceneData
        if !settings.defaultSceneName.isEmpty {
            setScene(sceneName: settings.defaultSceneName)
        }
    }

    func createDataCacheSystem() async -> DataCacheSystem {
        return DataCacheSystem()
    }

    // MARK: - Session Management
    /// Start a C3D analytics session.
    /// This method will start various recorders like the gaze recorder.
    ///  Note: in visionOS, gazes are recorded when an immersive space is opened.  The start session method will post an empty gaze record to get the manadatory session properties sent to the C3D back end.
    public func startSession() async -> Bool {

        guard isConfigured else {
            let error = "Attempted to start session when the C3D SDK is not configured"
            if logger != nil {
                logger?.error(error)
            } else {
                // The Cognitive logger instance is not available...
                // Note: the Cognitive logger (above) is a wrapper around the OS Logger.
                let osLogger = Logger(subsystem: "com.cognitive3d.analytics", category: "default")
                osLogger.error("Error: \(error)")
            }
            return false
        }

        guard !isSessionActive else {
            logger?.warning("Attempted to start an already active session")
            return false
        }

        guard let eventRecorder = customEventRecorder else {
            logger?.error("Cannot start session: No event recorder available")
            return false
        }

        guard let config = self.config else {
            return false
        }

        logger?.info(
            """
            Cognitive3DAnalyticsCore startSession
            \t‣ Session: id \(getSessionId()) (timestamp+id)
            \t‣ World tracking active: \(arSessionManager.isTrackingActive)
            """
        )

        // Start AR tracking
        await arSessionManager.startTracking()

        if config.shouldEndSessionOnIdle {
            setupIdleDetection(idleThreshold: config.idleThreshold)
        }

        // Record session start
        let position = coordSystem.convertPosition(getCurrentHMDPosition())

        guard
            eventRecorder.recordEvent(
                name: "c3d.sessionStart",
                position: position,
                properties: [:],
                immediate: true
            )
        else {
            logger?.error("Failed to record session start event")
            return false
        }

        // Send the batch immediately after recording the session start event
        eventRecorder.sendBatchedEvents()

        isSessionActive = true

        // We want to send the required session properties etc. by using a gaze record.
        sendMandatorySessionProperties()

        if isGazeTrackerStartedOnStart {
            Task { await gazeTracker?.startTracking() }
        }

        startSensorRecorders()

        #if !targetEnvironment(simulator)
            if let config = self.config, config.isHandTrackingRequired {
                // Register hands as dynamic objects.
                HandTracking.configure()
            }
        #endif

        sessionEventPublisher.send(.started(sessionId: getSessionId()))

        return true
    }

    @discardableResult
    public func endSession() async -> Bool {
        guard isSessionActive else {
            logger?.info("Cannot end session, not active")
            return false
        }

        guard let eventRecorder = customEventRecorder else {
            logger?.error("Cannot end session: No event recorder available")
            return false
        }

        logger?.info("Cognitive3DAnalyticsCore endSession")

        let position = coordSystem.convertPosition(getCurrentHMDPosition())

        // Record session end
        guard
            eventRecorder.recordEvent(
                name: "c3d.sessionEnd",
                position: position,
                properties: ["sessionlength": getTimestamp() - getSessionTimestamp()],
                immediate: true
            )
        else {
            logger?.error("Failed to record session end event")
            return false
        }

        // Stop sensor recording like the frame rate.
        stopSensorRecorders()

        // Now end the sessions which will post the data to the back end.
        endSessionRecorders()

        await sendData()
        await cleanUp()

        logger?.info("Session successfully ended")
        return true
    }

    private func cleanUp() async {
        isSessionActive = false

        // Notify subscribers
        sessionEventPublisher.send(.ended(sessionId: sessionId, state: sessionState))

        cleanUpIdleDetection()

        // Post any data that have been recorded.
        await customEventRecorder?.endSession()
        gazeTracker?.endSession()
        await dynamicDataManager?.endSession()
        await dynamicDataManager?.clearEngagements()
        await sensorRecorder?.endSession()

        stopSensorRecorders()

        sessionTimestamp = -1
        // Now we can clear the sssion id.
        sessionId = ""

        clearSessionProperties()
        clearParticipantProperties()
    }

    private func clearSessionProperties() {
        clearNewSessionProperties()
        allSessionProperties.removeAll()
        preSessionProperties.removeAll()
    }

    // MARK - sensors
    // Extend this method as needed if new internal sensor types are being added.
    func configureSensorRecording(_ sceneData: SceneData) {
        sensorRecorder = SensorRecorder(cog: self, sceneData: sceneData)

        // Sensor readings automatically recorded by the SDK.
        pitchRecorder = PitchRecorder(sensorRecorder: sensorRecorder!)
        yawRecorder = YawRecorder(sensorRecorder: sensorRecorder!)
        frameRateRecorder = FrameRateRecorder(sensorRecorder: sensorRecorder!)
        batteryLevelRecorder = BatteryLevelRecorder(sensorRecorder: sensorRecorder!)
    }

    func startSensorRecorders() {
        logger?.verbose("start internal sensor recorders")

        sensorRecorder?.startSessionTimer()

        if let isRecordingFPS = config?.isRecordingFPS, isRecordingFPS {
            frameRateRecorder?.startTracking()
        }

        if let recordingPitch = config?.isRecordingPitch, recordingPitch {
            pitchRecorder?.startTracking()
        }

        if let recordingYaw = config?.isRecordingYaw, recordingYaw {
            yawRecorder?.startTracking()
        }

        if let isRecordingBatteryLevel = config?.isRecordingBatteryLevel, isRecordingBatteryLevel {
            batteryLevelRecorder?.startTracking()
        }
    }

    func endSessionRecorders() {
        logger?.verbose("end sessions for internal sensor recorders")

        // We want to log the current battery level when a session is ended.
        if let isRecordingBatteryLevel = config?.isRecordingBatteryLevel, isRecordingBatteryLevel {
            batteryLevelRecorder?.endSession()
        }
    }

    /// Stop the various recorders that may be active.
    func stopSensorRecorders() {
        logger?.verbose("stop internal sensor recorders")

        // Stop the sensor recorder timer
        sensorRecorder?.stopSessionTimer()

        if let isRecordingFPS = config?.isRecordingFPS, isRecordingFPS {
            frameRateRecorder?.stop()
        }

        if let isRecordingPitch = config?.isRecordingPitch, isRecordingPitch {
            pitchRecorder?.stop()
        }

        if let isRecordingYaw = config?.isRecordingYaw, isRecordingYaw {
            yawRecorder?.stop()
        }

        if let isRecordingBatteryLevel = config?.isRecordingBatteryLevel, isRecordingBatteryLevel {
            batteryLevelRecorder?.stop()
        }
    }

    /// We want to send through the mandatory data for a session.
    /// This typically would be done when an immersive space is opened than gaze tracking is happening.
    /// But there are cases when the app has not yet opened an immersive space; this work around
    ///  create a gaze batch with an empty array with the session properties to the back end.
    func sendMandatorySessionProperties() {
        Task {
            try await gazeTracker?.sendMandatoryData()
        }
    }

    // MARK: - Internal Accessors

    func getConfig() -> Config {
        guard let config = config else {
            fatalError("Configuration not initialized")
        }
        return config
    }

    func getLog() -> CognitiveLog? {
        return logger
    }

    /// Get the id of the current scene; the scene id is esssential for the association of the data with a specifc scene on the Cognitive3D platform.
    public func getCurrentSceneId() -> String {
        return currentSceneId
    }

    internal func getCurrentSceneVersionNumber() -> Int {
        return currentSceneVersionNumber
    }

    func getCurrentSceneVersionId() -> Int {
        return currentSceneVersionId
    }

    // MARK: - Public Accessors

    public func getSessionTimestamp() -> Double {
        if sessionTimestamp < 0 {
            sessionTimestamp = getTimestamp()
        }
        return sessionTimestamp
    }

    public func getTimestamp() -> Double {
        return Date().timeIntervalSince1970
    }

    public func getSessionId() -> String {
        if sessionId.isEmpty {
            sessionId = "\(Int(getSessionTimestamp()))_\(userId)"
        }
        return sessionId
    }

    public func getUserId() -> String {
        return userId
    }

    public func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    public func getApiKey() -> String? {
        return config?.applicationKey
    }

    // MARK: - Session properties
    func setLobbyId(lobbyId: String) {
        self.lobbyId = lobbyId
    }

    func getLobbyId() -> String {
        return lobbyId
    }

    /// Set a key value property to add to the session data.
    public func setSessionProperty(key: String, value: Any) {
        // Update or add to known session properties
        allSessionProperties[key] = value

        // Update or add to new session properties
        newSessionProperties[key] = value
    }

    // Optional utility methods
    internal func clearNewSessionProperties() {
        newSessionProperties.removeAll()
    }

    /// Get the new sessions properties.
    /// - Parameters:
    ///     - clear: set to true to clear the properties
    internal func getNewSessionProperties(clear: Bool = false) -> [String: Any] {
        let properties = newSessionProperties

        if clear {
            clearNewSessionProperties()
        }

        return properties
    }

    /// Set a tag property for the current session
    public func setSessionTag(_ tag: String, setValue: Bool = true) {
        guard !tag.isEmpty else {
            logger?.warning("Warning: Session Tag cannot be empty!")
            return
        }

        guard tag.count <= 12 else {
            logger?.warning("Warning: Session Tag must be less than 12 characters!")
            return
        }

        setSessionProperty(key: "c3d.session_tag." + tag, value: setValue)
    }

    func setDeviceName(name: String) {
        deviceId = name
        allSessionProperties["c3d.deviceid"] = name
        newSessionProperties["c3d.deviceid"] = name
    }

    func setSessionName(_ sessionName: String) {
        allSessionProperties["c3d.sessionname"] = sessionName
        newSessionProperties["c3d.sessionname"] = sessionName
    }

    // MARK: - Participants

    /// Set properties that get associated with a participant like a name or id.
    public func setParticipantProperty(keySuffix: String, value: String) {
        let key = "c3d.participant." + keySuffix
        allSessionProperties[key] = value
        newSessionProperties[key] = value
    }

    /// Set participant id for a session; the id is unique identifier for a participant.
    public func setParticipantId(_ participantId: String) {
        self.participantId = participantId
        setParticipantProperty(keySuffix: "id", value: participantId)
    }

    /// Get the participant id.
    public func getParticipantId() -> String {
        return participantId
    }

    /// Set the full name for a participant.  The participant name gets used when there is no session name set.
    public func setParticipantFullName(_ participantName: String) {
        self.participantName = participantName
        setParticipantProperty(keySuffix: "name", value: participantName)
        if sessionName.isEmpty {
            setSessionName(participantName)
        }
    }

    /// Get the full name of the participant.
    public func getParticipantFullName() -> String {
        return participantName
    }

    private func clearParticipantProperties() {
        participantId = ""
        participantName = ""
    }

    // MARK: - Scene Management

    func setScene(sceneName: String) {
        logger?.info("setScene: '\(sceneName)'")

        Task {
            if !currentSceneId.isEmpty {
                await sendData()
            }

            var foundScene = false
            for sceneData in config?.allSceneData ?? [] {
                if sceneData.sceneName == sceneName {
                    if sceneData.sceneId.isEmpty {
                        logger?.error("Invalid scene configuration: Empty scene ID for scene \(sceneName)")
                        return
                    }

                    currentSceneId = sceneData.sceneId
                    currentSceneVersionNumber = sceneData.versionNumber
                    currentSceneVersionId = sceneData.versionId
                    foundScene = true

                    // Update EventRecorder with new scene data
                    customEventRecorder = EventRecorder(
                        cog: self,
                        sceneData: sceneData,
                        batchSize: config?.customEventBatchSize ?? 10
                    )

                    // Update the dynamic data manager with the new scene.
                    await dynamicDataManager?.updateScene(
                        sceneId: currentSceneId,
                        version: currentSceneVersionNumber
                    )
                    break
                }
            }

            if !foundScene {
                logger?.error("Config scene ids do not contain key for scene \(sceneName)")
                currentSceneId = ""
                currentSceneVersionNumber = 0
                currentSceneVersionId = 0
            } else {
                newSessionProperties = allSessionProperties
                await dynamicDataManager?.refreshObjectManifest()
            }
        }
    }

    /// Update the properties for the scene associated the manager.
    /// - Parameters:
    ///     -   sceneId: the unique string ID for the scene.
    ///     -   version: the version of the scene.
    ///     -   versionId: the version ID which is used with exit poll surveys.
    public func setSceneById(sceneId: String, version: Int = 1, versionId: Int) {
        Task {
            if !currentSceneId.isEmpty {
                await sendData()
            }

            if !sceneId.isEmpty {
                currentSceneId = sceneId
                currentSceneVersionNumber = version
                currentSceneVersionId = versionId
                newSessionProperties = allSessionProperties
                // It is essential to update the dynamc data manager when the current scene has changed.
                await dynamicDataManager?.updateScene(sceneId: sceneId, version: version)
            }
        }
    }

    func getSceneId() -> String {
        return currentSceneId
    }

    // MARK: - Data Management
    func sendData() async {
        guard isSessionActive else {
            logger?.warning("Cognitive3DAnalyticsCore sendData: no session active")
            return
        }

        if let eventRecorder = customEventRecorder {
            eventRecorder.sendBatchedEvents()
        }

        if let tracker = gazeTracker {
            do {
                _ = try await tracker.sendData()
            } catch GazeRecorderError.noDataAvailable {
                logger?.info("No gaze data available to send")
            } catch {
                logger?.error("Failed to send gaze data: \(error)")
            }
        }

        if let sensorRecorder = sensorRecorder {
            await sensorRecorder.sendData()
        }

        await dynamicDataManager?.sendData()

        // Upload any cached content
        if let dataCacheSystem = dataCacheSystem {
            await dataCacheSystem.uploadCachedContent()
        }
    }

    // MARK: - Device Properties

    func devicePropertyToString(propertyType: DeviceProperty) -> String {
        switch propertyType {
        case .appName: return "c3d.app.name"
        case .appVersion: return "c3d.app.version"
        case .appEngine: return "c3d.app.engine"
        case .appEngineVersion: return "c3d.app.engine.version"
        case .deviceType: return "c3d.device.type"
        case .deviceModel: return "c3d.device.model"
        case .deviceMemory: return "c3d.device.memory"
        case .deviceOS: return "c3d.device.os"
        case .deviceCPU: return "c3d.device.cpu"
        case .deviceCPUCores: return "c3d.device.cpu.cores"
        case .deviceCPUVendor: return "c3d.device.cpu.vendor"
        case .deviceGPU: return "c3d.device.gpu"
        case .deviceGPUDriver: return "c3d.device.gpu.driver"
        case .deviceGPUVendor: return "c3d.device.gpu.vendor"
        case .deviceGPUMemory: return "c3d.device.gpu.memory"
        case .vrModel: return "c3d.vr.model"
        case .vrVendor: return "c3d.vr.vendor"
        }
    }

    // MARK: - Version

    public static var version: String {
        return Bundle(for: Cognitive3DAnalyticsCore.self).infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "unknown"
    }

    // MARK: - Convenience methods
    internal var coordSystem: CoordinateSystem {
        return getConfig().targetCoordinateSystem
    }

    // TODO: refactor? The aspiration is to be able to change the debug logging levels at any time.
    private func updateLoggingLevelForAllComponents(level: LogLevel) {
        customEventRecorder?.getLog().setLoggingLevel(level: level)
        gazeTracker?.getLog().setLoggingLevel(level: level)
        sensorRecorder?.getLog().setLoggingLevel(level: level)
        ARSessionManager.shared.getLog().setLoggingLevel(level: level)
    }

    // MARK: - Network Connectivity Support

    private func setupConnectivitySupport() async {
        // Initialize and start the sync service
        await AnalyticsSyncService.shared.startNetworkMonitoring(core: self)
    }
}

// MARK: - Custom Events
extension Cognitive3DAnalyticsCore {

    @available(*, deprecated, message: "Use CustomEvent initializer directly instead")
    public func createEvent(_ name: String) -> CustomEvent {
        return CustomEvent(name: name, core: self)
    }

    @available(*, deprecated, message: "Use CustomEvent initializer directly instead")
    public func createEvent(_ name: String, properties: [String: Any]) -> CustomEvent {
        return CustomEvent(name: name, properties: properties, core: self)
    }

    /// Internal method to record custom events
    /// - Parameters:
    ///   - name: Event name/category
    ///   - position: Optional 3D position of the event
    ///   - properties: Additional properties for the event
    ///   - dynamicObjectId: Optional ID of a dynamic object associated with this event
    ///   - immediate: Whether to send immediately or batch
    /// - Returns: Success status
    @discardableResult
    public func recordCustomEvent(
        name: String,
        position: [Double]?,
        properties: [String: Any],
        dynamicObjectId: String? = nil,
        immediate: Bool
    ) -> Bool {
        guard let eventRecorder = customEventRecorder else {
            logger?.error("Cannot record custom event: No event recorder available")
            return false
        }

        guard !currentSceneId.isEmpty else {
            logger?.error("Cannot record event: No scene set")
            return false
        }

        let finalPosition = position ?? defaultPos
        return eventRecorder.recordEvent(
            name: name,
            position: finalPosition,
            properties: properties,
            immediate: immediate
        )
    }

    @discardableResult
    internal func recordDynamicCustomEvent(
        name: String,
        position: [Double]?,
        properties: [String: Any],
        dynamicObjectId: String,
        immediate: Bool
    ) -> Bool {
        guard let eventRecorder = customEventRecorder else {
            logger?.error("Cannot record dynamic custom event: No event recorder available")
            return false
        }

        guard !currentSceneId.isEmpty else {
            logger?.error("Cannot record dynamic event: No scene set")
            return false
        }

        let finalPosition = position ?? defaultPos

        // Use the recordDynamicEvent method from EventRecorder
        return eventRecorder.recordDynamicEvent(
            name: name,
            position: finalPosition,
            properties: properties,
            dynamicObjectId: dynamicObjectId,
            immediate: immediate
        )
    }

    // MARK: -
    /// Creates a new custom event related to a dynamic object
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    public func beginEngagement(objectId: String, engagementName: String) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot begin engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.beginEngagement(
            objectId: objectId,
            engagementName: engagementName
        )
    }

    /// Creates a new custom event related to a dynamic object with a unique ID
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: A unique identifier for this engagement
    public func beginEngagement(objectId: String, engagementName: String, uniqueEngagementId: String) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot begin engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.beginEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId
        )
    }

    /// Creates a new custom event related to a dynamic object with properties
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: A unique identifier for this engagement
    ///   - properties: Properties for the event
    public func beginEngagement(
        objectId: String,
        engagementName: String,
        uniqueEngagementId: String,
        properties: [String: Any]
    ) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot begin engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.beginEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId,
            properties: properties
        )
    }

    /// Ends an existing custom event related to a dynamic object
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    public func endEngagement(objectId: String, engagementName: String) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot end engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.endEngagement(
            objectId: objectId,
            engagementName: engagementName
        )
    }

    /// Ends an existing custom event related to a dynamic object with a unique ID
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: The unique identifier for this engagement
    public func endEngagement(objectId: String, engagementName: String, uniqueEngagementId: String) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot end engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.endEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId
        )
    }

    /// Ends an existing custom event related to a dynamic object with properties
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: The unique identifier for this engagement
    ///   - properties: Additional properties to add when ending
    public func endEngagement(
        objectId: String,
        engagementName: String,
        uniqueEngagementId: String,
        properties: [String: Any]
    ) async {
        guard let dynamicManager = dynamicDataManager else {
            logger?.warning("Cannot end engagement: Dynamic manager not available")
            return
        }

        await dynamicManager.endEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId,
            properties: properties
        )
    }

    /// Convience method to get the HMD position
    /// If world tracking is not available use the default position
    internal func getCurrentHMDPosition() -> [Double] {
        if arSessionManager.isTrackingActive, let position = arSessionManager.getPosition() {
            return position
        }
        return defaultPos
    }
}
