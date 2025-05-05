//
//  EventRecorder.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The `EventRecorder` is one of the primary recorders in the C3D SDK. The SDK uses this class to records events like `c3d.sessionStart` and `c3d.sessionEnd`
/// as well as supporting custom events created by application developers. The events get posted to the backend where they can be viewed in the session pages and SceneExplorer on the Cognitive3D dashboard.
/// See also:  ``CustomEvent`` .
public class EventRecorder {
    // MARK: - Properties
    private var core: Cognitive3DAnalyticsCore
    private var batchedEvents: [EventData] = []
    private var jsonPart = 1
    private let networkClient: NetworkAPIClient
    private let sceneData: SceneData
    private let logger: CognitiveLog
    private var isSending = false
    private let batchSize: Int

    // Time-based sending properties
    private let sendInterval: TimeInterval = 10.0  // Send data every 10 seconds
    private var nextSendTimestamp: Double = 0
    private var eventBatchTimer: Timer?

    // MARK: - Initialization
    public init(cog: Cognitive3DAnalyticsCore, sceneData: SceneData, batchSize: Int = 10) {
        core = cog
        self.sceneData = sceneData
        self.batchSize = batchSize
        logger = CognitiveLog(category: "EventRecorder")
        let config = cog.getConfig()
        networkClient = NetworkAPIClient(apiKey: config.applicationKey, cog: cog)

        // Initialize next send timestamp
        nextSendTimestamp = Date().timeIntervalSince1970 + sendInterval

        // Inherit log level from core
        if let coreLogger = core.getLog() {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }

        // Start time checking
        startTimeChecking()
    }

    // MARK: - Event Recording
    @discardableResult
    public func recordEvent(
        name: String,
        position: [Double],
        properties: [String: Any],
        immediate: Bool,
        bypassActiveCheck: Bool = false
    ) -> Bool {
        // Special handling for session events
        let isSessionEvent = name == "c3d.sessionStart" || name == "c3d.sessionEnd"

        // Only check session active state for non-session events
        if !isSessionEvent && !core.isSessionActive && !bypassActiveCheck {
            logger.error("Cannot record event: Session not active")
            return false
        }

        guard !sceneData.sceneId.isEmpty else {
            logger.error("Cannot record event: No valid scene ID")
            return false
        }

        logger.info(
            """
            Recording event ‣ Name: '\(name)'
            \t‣ Position: \(position)
            \t‣ Properties: \(properties)
            \t‣ Timestamp: \(core.getTimestamp())
            """
        )

        let eventData = EventData(
            name: name,
            time: core.getTimestamp(),
            point: position.map { Double($0) },
            properties: properties.mapValues { self.convertToFreeformData($0) },
            dynamicObjectId: nil
        )

        // Handle immediate mode
        if immediate {
            return sendImmediateEvent(eventData)
        }

        // Otherwise use the batch system
        return batchEvent(eventData)
    }

    internal func recordEventForSession(id: String, name: String, position: [Double], properties: [String: Any]) async
        -> Bool
    {
        guard !sceneData.sceneId.isEmpty else {
            logger.error("Cannot record event: No valid scene ID")
            return false
        }

        logger.info(
            """
            Recording event for session \(id) ‣ Name: '\(name)'
            \t‣ Position: \(position)
            \t‣ Properties: \(properties)
            \t‣ Timestamp: \(core.getTimestamp())
            """
        )

        let eventData = EventData(
            name: name,
            time: core.getTimestamp(),
            point: position.map { Double($0) },
            properties: properties.mapValues { self.convertToFreeformData($0) },
            dynamicObjectId: nil
        )

        // Session events now use the regular batch system
        return batchEvent(eventData)
    }

    @discardableResult
    public func recordDynamicEvent(
        name: String,
        position: [Double],
        properties: [String: Any],
        dynamicObjectId: String,
        immediate: Bool
    ) -> Bool {
        // Special handling for session events
        let isSessionEvent = name == "c3d.sessionStart" || name == "c3d.sessionEnd"

        // Only check session active state for non-session events
        if !isSessionEvent && !core.isSessionActive {
            logger.error("Cannot record dynamic event: Session not active")
            return false
        }

        guard !sceneData.sceneId.isEmpty else {
            logger.error("Cannot record dynamic event: No valid scene ID")
            return false
        }

        logger.info(
            """
            Recording dynamic event ‣ Name: '\(name)'
            \t‣ Position: \(position)
            \t‣ Dynamic Object ID: \(dynamicObjectId)
            \t‣ Properties: \(properties)
            \t‣ Timestamp: \(core.getTimestamp())
            """
        )

        let eventData = EventData(
            name: name,
            time: core.getTimestamp(),
            point: position.map { Double($0) },
            properties: properties.mapValues { self.convertToFreeformData($0) },
            dynamicObjectId: dynamicObjectId
        )

        // Handle immediate mode if specified
        if immediate {
            return sendImmediateEvent(eventData)
        }

        // Otherwise use the batch system
        return batchEvent(eventData)
    }

    // MARK: - Private Methods
    private func convertToFreeformData(_ value: Any) -> FreeformData {
        switch value {
        case let stringValue as String: return .string(stringValue)
        case let numberValue as Double: return .number(numberValue)
        case let boolValue as Bool: return .boolean(boolValue)
        default: return .string(String(describing: value))
        }
    }

    private func batchEvent(_ eventData: EventData) -> Bool {
        batchedEvents.append(eventData)

        logger.verbose("Added event to batch. Current batch size: \(batchedEvents.count)")

        let currentTime = Date().timeIntervalSince1970

        // Send if batch size threshold is reached or time interval has elapsed
        if batchedEvents.count >= batchSize || currentTime >= nextSendTimestamp {
            logger.verbose("Sending events batch, count: \(batchedEvents.count)")
            let result = sendBatchedEvents()
            if currentTime >= nextSendTimestamp {
                nextSendTimestamp = currentTime + sendInterval
                logger.verbose("Updated next send timestamp to: \(nextSendTimestamp)")
            }
            return result
        }
        return true
    }


    private func sendImmediateEvent(_ eventData: EventData) -> Bool {
        // Create a single-event batch
        let event = createEventBatch(eventsToSend: [eventData])

        // Start a background task to handle the async work
        Task {
            _ = await sendEventBatch(event: event, eventsToSend: [eventData])
        }

        // Return true immediately, as we've launched the background task
        return true
    }

    @discardableResult
    func sendBatchedEvents() -> Bool {
        guard !batchedEvents.isEmpty else {
            logger.verbose("No events to send")
            return true
        }

        guard !isSending else {
            logger.warning("Send already in progress, skipping")
            return false
        }

        isSending = true
        let eventsToSend = batchedEvents
        batchedEvents.removeAll()

        let event = createEventBatch(eventsToSend: eventsToSend)

        // Launch the async task in the background
        Task {
            let success = await sendEventBatch(event: event, eventsToSend: eventsToSend)

            // Handle result in the background
            if !success {
                logger.warning("Failed to send event batch")
            }

            // Make sure to reset the sending flag
            isSending = false
        }

        // Return true to indicate the batch was scheduled for sending
        return true
    }

    private func createEventBatch(eventsToSend: [EventData]) -> Event {
        return Event(
            userId: core.getUserId(),
            timestamp: core.getSessionTimestamp(),
            sessionId: core.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            data: eventsToSend
        )
    }

    private func sendEventBatch(event: Event, eventsToSend: [EventData]) async -> Bool {
        do {
            let response: EventResponse = try await networkClient.makeRequest(
                endpoint: "events",
                sceneId: sceneData.sceneId,
                version: String(sceneData.versionNumber),
                method: .post,
                body: event
            )

            if response.received {
                jsonPart += 1
                logger.verbose("Batch of \(eventsToSend.count) events sent successfully")
                return true
            } else {
                logger.warning("Failed to send batch - server did not accept the data")
                await handleSendFailure(event: event, eventsToSend: eventsToSend)
                return false
            }
        } catch let error {
            logger.error("Failed to send batched events: \(error)")
            await handleSendFailure(event: event, eventsToSend: eventsToSend, error: error)
            return false
        }
    }

    // MARK: - code for periodic updates to post data
    /// Starts periodic checking for time-based event batching
    private func startTimeChecking() {
        // Already have a timer running
        if eventBatchTimer != nil {
            return
        }

        // Create timer with half the send interval for more responsive checking
        eventBatchTimer = Timer(timeInterval: sendInterval/2, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task {
                await self.checkAndSendData()
            }
        }

        // Add to RunLoop
        RunLoop.main.add(eventBatchTimer!, forMode: .common)
    }

    /// Stops the timer and cleans up
    private func stopTimeChecking() {
        if eventBatchTimer != nil {
            eventBatchTimer?.invalidate()
            eventBatchTimer = nil
        }
    }

    /// Checks if time interval has elapsed and sends batched events if needed
    private func checkAndSendData() async {
        let currentTime = Date().timeIntervalSince1970

        if currentTime >= nextSendTimestamp {
            if !batchedEvents.isEmpty {
                _ = sendBatchedEvents()
            }

            nextSendTimestamp = currentTime + sendInterval
        }
    }

    // MARK: - error handling
    private func handleSendFailure(event: Event, eventsToSend: [EventData], error: Error? = nil) async {
        // Check if it's a network error that should be cached
        if let error = error, core.isNetworkError(error) {
            logger.info("Network error detected, caching event data for later upload")
            await cacheEventData(event: event, eventsToSend: eventsToSend)
        } else {
            // For non-network errors or when no specific error is provided, restore events to the batch queue
            restoreEventsToQueue(eventsToSend)
        }
    }

    private func cacheEventData(event: Event, eventsToSend: [EventData]) async {
        do {
            // Encode event data for caching
            let jsonData = try JSONEncoder().encode(event)

            // Use DataCacheSystem to cache the request
            if let dataCache = core.dataCacheSystem {
                // Get the correct URL from NetworkEnvironment
                guard
                    let url = NetworkEnvironment.current.constructEventsURL(
                        sceneId: sceneData.sceneId,
                        version: sceneData.versionNumber
                    )
                else {
                    logger.error("Failed to create URL for event data")
                    restoreEventsToQueue(eventsToSend)
                    return
                }

                await dataCache.cacheRequest(url: url, body: jsonData)
                // Add explicit logging to show events were cached
                logger.info("Successfully cached \(eventsToSend.count) events for later transmission")
                print("Events data successfully cached - count: \(eventsToSend.count)")
            } else {
                logger.warning("DataCacheSystem not available - unable to cache event data")
                restoreEventsToQueue(eventsToSend)
            }
        } catch {
            logger.error("Failed to encode event data for caching: \(error)")
            restoreEventsToQueue(eventsToSend)
        }
    }

    private func constructEventsURL() -> URL? {
        return NetworkEnvironment.current.constructEventsURL(
            sceneId: sceneData.sceneId,
            version: sceneData.versionNumber
        )
    }

    private func restoreEventsToQueue(_ eventsToSend: [EventData]) {
        batchedEvents.append(contentsOf: eventsToSend)
        logger.info("Restored \(eventsToSend.count) events to batch queue")
    }

    func endSession() async {
        logger.verbose("Event recorder: ending session")

        // Stop time checking
        stopTimeChecking()

        if !batchedEvents.isEmpty {
            logger.info("Processing \(batchedEvents.count) remaining events before session end")
            _ = sendBatchedEvents()
        }
    }

    /// Send all pending events
    /// - Returns: Success status
    @discardableResult
    public func sendAllPendingEvents() -> Bool {
        return sendBatchedEvents()
    }

    /// Send all pending events before changing scenes
    /// - Returns: Success status
    @discardableResult
    public func sendDataBeforeSceneChange()  -> Bool {
        logger.info("Sending all pending event data before scene change")
        return sendBatchedEvents()
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
