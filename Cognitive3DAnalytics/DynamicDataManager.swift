//
//  DynamicDataManager.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-01-31.
//

import Foundation
import Observation
import RealityKit

/// Settings for dynamic object tracking behavior
public struct DynamicObjectSettings {
    /// Update interval for dynamic objects in seconds
    public let updateInterval: Float
    /// Position threshold for recording changes (in meters)
    public let positionThreshold: Float
    /// Rotation threshold for recording changes (in degrees)
    public let rotationThreshold: Float
    /// Scale threshold for recording changes
    public let scaleThreshold: Float

    public init(
        updateInterval: Float = 0.1,
        positionThreshold: Float = 0.01,
        rotationThreshold: Float = 1.0,
        scaleThreshold: Float = 0.01
    ) {
        self.updateInterval = updateInterval
        self.positionThreshold = positionThreshold
        self.rotationThreshold = rotationThreshold
        self.scaleThreshold = scaleThreshold
    }
}

// Default settings to use if none are provided
private let defaultSettings = DynamicObjectSettings()

/// Tracks the state of a dynamic object with an associated timestamp.
internal struct DynamicObjectState {
    var lastPosition: SIMD3<Float> = .zero
    var lastRotation: simd_quatf = simd_quatf(angle: 0, axis: .zero)
    var lastScale: SIMD3<Float> = .one
    var lastUpdateTime: TimeInterval = 0
}

/// Manager actor for handling dynamic objects at run-time in the C3D analytics SDK.
public actor DynamicDataManager {
    // MARK: - Properties
    /// The queued events get posted to the C3D server when the snapshot threshold is met.
    private var queuedEvents: [DynamicEventData] = []
    internal weak var core: Cognitive3DAnalyticsCore?
    private let networkClient: NetworkAPIClient
    internal let logger = CognitiveLog(category: "DynamicDataManager")
    private var jsonPart: Int = 1
    private var isSending = false

    // Track last state for each dynamic object; the state being transform data with a time stamp.
    internal var lastStates: [String: DynamicObjectState] = [:]

    // Manifest tracking
    /// The active manifest entries are the currently dynamic objects in the scene.
    internal var activeManifests: [String: ManifestEntry] = [:]
    /// State information for debugging purposes to know if a manifest entry has been updated.
    private var pendingManifestUpdates: Set<String> = []

    // Settings - the various thresholds etc. for the dynamic object manager.
    private var settings: DynamicObjectSettings

    // Scene tracking
    private var currentSceneId: String = ""
    private var currentSceneVersion: Int = 0

    // Constants for batching network requests
    private let snapshotThreshold = 128
    private let sendInterval: TimeInterval = 2.0
    private var nextSendTimestamp: Double = 0

    /// Controls whether manifest data should be sent when changes are detected
    public var shouldSendManifestsOnChange = true

    /// Properties used for dynamic objects that are being updated using the gaze tracker.
    internal var syncedObjects: Set<String> = []
    internal var gazeSyncUpdates: [String: Int] = [:]

    private var engagements: [String: CustomEvent] = [:]

    public init(core: Cognitive3DAnalyticsCore) {
        self.core = core
        self.settings = defaultSettings
        self.networkClient = NetworkAPIClient(
            apiKey: core.getConfig().applicationKey,
            cog: core
        )

        // Inherit log level from core
        if let coreLogger = core.getLog() {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }
    }

    // MARK: - Settings Management
    public func updateSettings(_ newSettings: DynamicObjectSettings) {
        self.settings = newSettings
    }

    // MARK: - Dynamic Object Registration with Initial State
    /// When a session is started, each dynamic object in a scene gets registered to enable snapshot recording.
    /// This version ensures the initial enabled state is properly recorded.
    public func registerDynamicObject(
        id: String,
        name: String,
        mesh: String,
        fileType: String = gltfFileType
    ) async {
        let sceneMesh = ManifestEntry(
            name: name,
            mesh: mesh,
            fileType: fileType
        )

        activeManifests[id] = sceneMesh
        pendingManifestUpdates.insert(id)

        // If we have an active session, immediately send the initial enabled state
        if let core = self.core, core.isSessionActive {
            // Create a placeholder state for this object if it doesn't exist
            if lastStates[id] == nil {
                lastStates[id] = DynamicObjectState()
            }

            // Force send the initial enabled:true property
            let initialProperties = [["enabled": AnyCodable(true)]]
            await recordDynamicObject(
                id: id,
                position: lastStates[id]!.lastPosition,
                rotation: lastStates[id]!.lastRotation,
                scale: lastStates[id]!.lastScale,
                positionThreshold: 0,
                rotationThreshold: 0,
                scaleThreshold: 0,
                updateRate: 0,
                properties: initialProperties
            )
        }
    }

    public func registerHand(id: String, isRightHand: Bool = true) {
        let properties: [String: AnyCodable] =
            isRightHand ? ["controller": AnyCodable("right")] : ["controller": AnyCodable("left")]

        let sceneMesh = ManifestEntry(
            name: isRightHand ? "RightHand" : "LeftHand",
            mesh: isRightHand ? "handRight" : "handLeft",
            fileType: gltfFileType,
            controllerType: isRightHand ? "hand_right" : "hand_left",
            properties: [properties]
        )

        activeManifests[id] = sceneMesh
        pendingManifestUpdates.insert(id)
    }

    /// When a dynamic object is removed from the scene in a session or disabled call this method to remove the object.
    /// This will stop it being udpated on the backend.
    public func removeDynamicObject(id: String) async {
        let lastState = lastStates[id]

        activeManifests[id] = nil
        lastStates.removeValue(forKey: id)

        if let state = lastState {
            let properties = [["enabled": AnyCodable(false)]]
            await recordDynamicObject(
                id: id,
                position: state.lastPosition,
                rotation: state.lastRotation,
                scale: state.lastScale,
                positionThreshold: 0,
                rotationThreshold: 0,
                scaleThreshold: 0,
                updateRate: 0,
                properties: properties
            )
        }
    }

    // MARK: - Scene Management
    /// Update the current scene associated with the manager
    public func updateScene(sceneId: String, version: Int) async {
        if self.currentSceneId != sceneId {
            self.currentSceneId = sceneId
            self.currentSceneVersion = version
            await refreshObjectManifest()
        }
    }

    // MARK: - Dynamic Object Recording
    public func recordDynamicObject(
        id: String,
        position: SIMD3<Float>,
        rotation: simd_quatf,
        scale: SIMD3<Float>,
        positionThreshold: Float,
        rotationThreshold: Float,
        scaleThreshold: Float,
        updateRate: Float,
        properties: [[String: AnyCodable]]? = nil
    ) async {
        guard let core = self.core else {
            logger.warning("Cannot record dynamic object snapshot - no core instance")
            return
        }

        // Check there is an active session.
        if !core.isSessionActive {
            return
        }

        let coordSystem = core.getConfig().targetCoordinateSystem
        let currentTime = Date().timeIntervalSince1970
        let state = lastStates[id] ?? DynamicObjectState()

        var hasChangesToRecord = false
        var hasScaleChanged = false

        // Force record if properties are provided
        if properties != nil {
            hasChangesToRecord = true
        }

        // Only check updateRate if we don't have properties to record
        if !hasChangesToRecord {
            guard currentTime >= state.lastUpdateTime + Double(updateRate) else {
                return
            }
        }

        // Check position threshold
        let positionDelta = distance(position, state.lastPosition)
        if positionDelta > positionThreshold {
            hasChangesToRecord = true
        }

        // Check rotation threshold
        let dotProduct = dot(rotation.vector, state.lastRotation.vector)
        let angle = acos(min(abs(dotProduct), 1.0)) * 2.0 * 180.0 / .pi
        if angle > rotationThreshold {
            hasChangesToRecord = true
        }

        // Check scale threshold
        let scaleDelta = distance(scale, state.lastScale)
        if scaleDelta > scaleThreshold {
            hasChangesToRecord = true
            hasScaleChanged = true
        }

        guard hasChangesToRecord else { return }

        // Convert quaternion components to array
        let rotationArray = [
            Double(rotation.vector.x),
            Double(rotation.vector.y),
            Double(rotation.vector.z),
            Double(rotation.real),
        ]

        let convertedPos = coordSystem.convertPosition(position.toDouble())
        let convertedRot = coordSystem.convertRotation(rotationArray)

        let event = DynamicEventData(
            id: id,
            time: currentTime,
            p: convertedPos,
            r: convertedRot,
            s: hasScaleChanged ? [Double(scale.x), Double(scale.y), Double(scale.z)] : nil,
            properties: properties,
            buttons: nil
        )

        queuedEvents.append(event)

        lastStates[id] = DynamicObjectState(
            lastPosition: position,
            lastRotation: rotation,
            lastScale: scale,
            lastUpdateTime: currentTime
        )

        Task {
            await checkAndSendData()
        }
    }

    // MARK: - Data Management
    private func checkAndSendData() async {
        let currentTime = Date().timeIntervalSince1970

        if queuedEvents.count >= snapshotThreshold || currentTime >= nextSendTimestamp {
            await sendData()
            nextSendTimestamp = currentTime + sendInterval
        }
    }

    public func sendData() async {
        guard !isSending,
            let core = core,
            !queuedEvents.isEmpty
        else {
            logger.verbose("No dynamic data to send or send already in progress.")
            return
        }

        isSending = true

        let eventsToSend = queuedEvents
        queuedEvents.removeAll()

        // Determine if manifests need to be included
        if shouldSendManifestsOnChange && !pendingManifestUpdates.isEmpty {
            await sendBatchWithManifests(events: eventsToSend, core: core)
        } else {
            await sendBatchWithoutManifests(events: eventsToSend, core: core)
        }

        isSending = false
    }

    private func sendBatchWithManifests(events: [DynamicEventData], core: Cognitive3DAnalyticsCore) async {
        // Only include the manifests that have pending updates
        let manifest = pendingManifestUpdates.reduce(into: [String: ManifestEntry]()) { result, id in
            if let entry = activeManifests[id] {
                result[id] = entry
            }
        }

        // Track which manifests we're attempting to send
        let pendingIds = pendingManifestUpdates
        pendingManifestUpdates.removeAll()

        // Prepare the batch with changed manifests
        let batch = createBatch(core: core, manifest: manifest, events: events)

        #if DEBUG
            logger.info("Batch dynamic objects \(manifest.count) in manifest")
        #else
            logger.verbose("Batch dynamic objects \(manifest.count) in manifest")
        #endif

        #if DEBUG
            logger.info("Batch dynamic  events \(events.count)")
        #else
            logger.verbose("Batch dynamic events \(events.count)")
        #endif

        do {
            let response = try await sendBatchRequest(
                batch: batch,
                sceneid: currentSceneId,
                version: currentSceneVersion
            )

            if response.received {
                jsonPart += 1
                #if DEBUG
                    logger.info("Dynamic batch with \(manifest.count) manifest entries sent successfully")
                #else
                    logger.verbose("Dynamic batch with \(manifest.count) manifest entries sent successfully")
                #endif
            } else {
                await handleSendFailure(events: events, pendingManifestIds: pendingIds)
            }
        } catch {
            await handleSendFailure(events: events, pendingManifestIds: pendingIds, error: error)
        }
    }

    private func sendBatchWithoutManifests(events: [DynamicEventData], core: Cognitive3DAnalyticsCore) async {
        // Create batch with empty manifest
        let batch = createBatch(core: core, manifest: [:], events: events)

        #if DEBUG
            logger.info("Batch dynamic events \(events.count)")
        #else
            logger.verbose("Batch dynamic events \(events.count)")
        #endif

        do {
            let response = try await sendBatchRequest(
                batch: batch,
                sceneid: currentSceneId,
                version: currentSceneVersion
            )

            if response.received {
                jsonPart += 1
                #if DEBUG
                    logger.info("Batch success")
                #else
                    logger.verbose("Batch success")
                #endif
            } else {
                Task {
                    await handleSendFailure(events: events)
                }
            }
        } catch {
            Task {
                await handleSendFailure(events: events, error: error)
            }
        }
    }

    private func createBatch(
        core: Cognitive3DAnalyticsCore,
        manifest: [String: ManifestEntry],
        events: [DynamicEventData]
    ) -> DynamicSession {
        return DynamicSession(
            userId: core.getUserId(),
            timestamp: Date().timeIntervalSince1970,
            sessionId: core.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            manifest: manifest,
            data: events
        )
    }

    private func sendBatchRequest(batch: DynamicSession, sceneid: String, version: Int) async throws -> EventResponse {
        return try await networkClient.makeRequest(
            endpoint: "dynamics",
            sceneId: sceneid,
            version: String(version),
            method: .post,
            body: batch
        )
    }

    /// Handle network errors; if the error is not an API error but a network error (500) etc. store the data in the local data cache.
    private func handleSendFailure(
        events: [DynamicEventData],
        pendingManifestIds: Set<String>? = nil,
        error: Error? = nil
    ) async {
        // Check if it's a network error that should be cached
        if let error = error, let core = self.core, core.isNetworkError(error) {
            logger.info("Network error detected, caching dynamic data for later upload")

            // Cache the data using DataCacheSystem
            do {
                // Create the batch to cache
                let manifestToCache =
                    pendingManifestIds?.reduce(into: [String: ManifestEntry]()) { result, id in
                        if let entry = activeManifests[id] {
                            result[id] = entry
                        }
                    } ?? [:]

                let batchToCache = createBatch(core: core, manifest: manifestToCache, events: events)

                // Encode the batch to JSON
                let jsonData = try JSONEncoder().encode(batchToCache)

                // Use the DataCacheSystem to cache the request
                if let dataCache = core.dataCacheSystem {
                    let sceneId = core.getCurrentSceneId()
                    let version = core.getCurrentSceneVersionNumber()
                    guard
                        let url = NetworkEnvironment.current.constructDynamicObjectsURL(
                            sceneId: sceneId,
                            version: version
                        )
                    else {
                        logger.error("Failed to create URL for gaze data")
                        return
                    }
                    await dataCache.cacheRequest(url: url, body: jsonData)
                }
            } catch {
                logger.error("Error encoding dynamic data for caching: \(error)")
            }
        }

        // If we failed to cache or it's not a network error, restore to queue as before
        // Restore events
        queuedEvents.append(contentsOf: events)

        // Restore pending manifest updates if provided
        if let pendingIds = pendingManifestIds {
            pendingManifestUpdates.formUnion(pendingIds)
        }

        if let error = error {
            logger.error("Error sending dynamic batch: \(error)")
        } else {
            logger.warning("Failed to send dynamic batch - data restored to queue")
        }
    }

    // MARK: - Private Manifest Handling
    private func sendManifestEntry(id: String, sceneMesh: ManifestEntry) async {
        guard let core = core else {
            logger.warning("Cannot send manifest entry - no core instance")
            return
        }

        let manifestData = DynamicSession(
            userId: core.getUserId(),
            timestamp: Date().timeIntervalSince1970,
            sessionId: core.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            manifest: [id: sceneMesh],
            data: []
        )

        do {
            let response: EventResponse = try await networkClient.makeRequest(
                endpoint: "dynamics",
                sceneId: currentSceneId,
                version: String(currentSceneVersion),
                method: .post,
                body: manifestData
            )
            if response.received {
                jsonPart += 1
                pendingManifestUpdates.remove(id)
                logger.verbose("Manifest entry sent successfully for ID: \(id)")
            } else {
                logger.warning("Failed to send manifest entry for ID: \(id)")
            }
        } catch {
            logger.error("Error sending manifest entry: \(error)")
        }
    }

    // MARK: - Manifest Management
    // Update refreshObjectManifest to just mark all entries as pending
    internal func refreshObjectManifest() async {
        guard !activeManifests.isEmpty else { return }
        pendingManifestUpdates = Set(activeManifests.keys)
    }

    // MARK: - Session Management
    internal func endSession() async {
        await sendData()
        queuedEvents.removeAll()
        pendingManifestUpdates.removeAll()
        jsonPart = 1
    }

    // MARK: - gaze sync'ing
    public func getObjectState(id: String) async -> (position: SIMD3<Float>, rotation: simd_quatf)? {
        if let state = lastStates[id] {
            return (state.lastPosition, state.lastRotation)
        }
        return nil
    }

    public func getGazeSyncInfo(id: String) async -> (totalSyncs: Int, isEnabled: Bool) {
        return (gazeSyncUpdates[id] ?? 0, syncedObjects.contains(id))
    }

    /// Begins an engagement with a dynamic object
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    public func beginEngagement(objectId: String, engagementName: String) async {
        await beginEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: "",
            properties: nil
        )
    }

    /// Begins an engagement with a dynamic object with a unique identifier
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: A unique identifier for this engagement
    public func beginEngagement(objectId: String, engagementName: String, uniqueEngagementId: String) async {
        await beginEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId,
            properties: nil
        )
    }

    /// Begins an engagement with a dynamic object with properties
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: A unique identifier for this engagement
    ///   - properties: Optional properties for the engagement
    public func beginEngagement(
        objectId: String,
        engagementName: String,
        uniqueEngagementId: String,
        properties: [String: Any]?
    ) async {
        guard let core = self.core, core.isSessionActive else {
            logger.warning("Cannot begin engagement: Session not active")
            return
        }

        // If uniqueEngagementId is empty, create one
        let finalUniqueId = uniqueEngagementId.isEmpty ? objectId + " " + engagementName : uniqueEngagementId

        // Create a new custom event
        let customEvent = CustomEvent(name: engagementName, properties: properties ?? [:], core: core)
            .setDynamicObject(objectId)

        // Check if there's an existing engagement with this ID
        if let existingEvent = engagements[finalUniqueId] {
            // Get the object position for the existing event
            var position: [Double] = [0, 0, 0]

            if let state = await getObjectState(id: objectId) {
                let convertedPos = core.getConfig().targetCoordinateSystem.convertPosition(
                    [Double(state.position.x), Double(state.position.y), Double(state.position.z)]
                )
                position = convertedPos
            }

            // Send the existing event
            existingEvent.send(position)

            // Replace with the new event
            engagements[finalUniqueId] = customEvent
        } else {
            // Add new event
            engagements[finalUniqueId] = customEvent
        }
    }

    /// Ends an engagement with a dynamic object
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    public func endEngagement(objectId: String, engagementName: String) async {
        await endEngagement(objectId: objectId, engagementName: engagementName, uniqueEngagementId: "", properties: nil)
    }

    /// Ends an engagement with a dynamic object using a unique ID
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: The unique identifier for this engagement
    public func endEngagement(objectId: String, engagementName: String, uniqueEngagementId: String) async {
        await endEngagement(
            objectId: objectId,
            engagementName: engagementName,
            uniqueEngagementId: uniqueEngagementId,
            properties: nil
        )
    }

    /// Ends an engagement with a dynamic object
    /// - Parameters:
    ///   - objectId: The ID of the dynamic object
    ///   - engagementName: The name of the engagement
    ///   - uniqueEngagementId: Optional unique identifier for this engagement
    ///   - properties: Optional properties to add to the event when ending
    public func endEngagement(
        objectId: String,
        engagementName: String,
        uniqueEngagementId: String,
        properties: [String: Any]?
    ) async {
        guard let core = self.core, core.isSessionActive else {
            logger.warning("Cannot end engagement: Session not active")
            return
        }

        let finalUniqueId = uniqueEngagementId.isEmpty ? objectId + " " + engagementName : uniqueEngagementId

        // Get the object position
        var position: [Double] = [0, 0, 0]

        if let state = await getObjectState(id: objectId) {
            let convertedPos = core.getConfig().targetCoordinateSystem.convertPosition(
                [Double(state.position.x), Double(state.position.y), Double(state.position.z)]
            )
            position = convertedPos
        }

        // Look for the existing engagement
        if let existingEvent = engagements[finalUniqueId] {
            // Add properties if provided
            if let props = properties {
                existingEvent.setProperties(props)
            }

            // Send the event
            existingEvent.send(position)

            // Remove from dictionary
            engagements.removeValue(forKey: finalUniqueId)
        } else {
            // Create and send a new event immediately
            let event = CustomEvent(name: engagementName, properties: properties ?? [:], core: core)
                .setDynamicObject(objectId)

            event.send(position)
        }
    }

    // Add to endSession method
    internal func clearEngagements() async {
        for (_, event) in engagements {
            event.send()
        }
        engagements.removeAll()
    }
}
