//
//  GazeDataManager.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import Observation

/// Data manager for gaze records.  The gaze records are created by the `GazeRecorder` class using world position tracking with an `ARSession`.
@Observable public class GazeDataManager {
    // MARK: - Properties
    private var gazeEvents: [GazeEventData] = []
    private let sessionStartTime: Double
    private var nextSendTimestamp: Double = 0
    private var jsonPart: Int = 1
    private weak var core: Cognitive3DAnalyticsCore?
    private var isSending = false
    private let networkClient: NetworkAPIClient

    /// debug logger instance
    private let logger = CognitiveLog(category: "GazeDataManager")

    /// local override  for debug
    private var isDebugVerbose = false

    /// The JSON body data can be quite long; we can constrain how much debug is printed out.
    private var isBodyDebugEnabled = false

    // Constants
    internal let sendInterval: TimeInterval = 2.0  // Send data every 2 seconds

    init(core: Cognitive3DAnalyticsCore) {
        self.core = core
        self.sessionStartTime = Date().timeIntervalSince1970
        let config = core.getConfig()
        self.networkClient = NetworkAPIClient(apiKey: config.applicationKey, cog: core)

        self.nextSendTimestamp = self.sessionStartTime + sendInterval

        // Inherit log level from core
        if let coreLogger = core.logger {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }
    }

    // MARK: - Gaze Recording Methods
    func recordGaze(_ event: GazeEventData) {
        gazeEvents.append(event)
        checkAndSendData()
    }

    // MARK: - Data Management
    private func checkAndSendData() {
        let currentTime = Date().timeIntervalSince1970
        if currentTime >= nextSendTimestamp {
            // TODO: handle errors
            _ = sendData()
            nextSendTimestamp = currentTime + sendInterval
        }
    }

    @discardableResult internal func sendData() -> Gaze? {
        guard !isSending, let core = core, !gazeEvents.isEmpty else {
            logger.verbose("No gaze events to send or send already in progress.")
            return nil
        }

        isSending = true

        let eventsBeingSent = gazeEvents

        #if DEBUG
        logger.info("Batch gazes with \(eventsBeingSent.count)")
        #endif

        gazeEvents.removeAll()

        // Get device properties struct, then convert to dictionary
        var sessionProperties = createDeviceProperties(core: core).toDictionary()
        // Merge any new session properties with the device properties
        let newSessionProperties = core.getNewSessionProperties(clear: true)
        sessionProperties = sessionProperties.merging(newSessionProperties) { (_, new) in new }

        let gaze = Gaze(
            userId: core.getUserId(),
            timestamp: Date().timeIntervalSince1970,
            sessionId: core.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            hmdType: visonProHmdType,
            interval: sendInterval,
            properties: sessionProperties,
            data: eventsBeingSent
        )

        Task {
            do {
                if isBodyDebugEnabled {
                    logGazeBody(gaze: gaze)
                }

                let response: GazeResponse = try await networkClient.makeRequest(
                    endpoint: "gaze",
                    sceneId: core.getCurrentSceneId(),
                    version: String(core.getCurrentSceneVersionNumber()),
                    method: .post,
                    body: gaze
                )

                if response.received {
                    jsonPart += 1
                    if isDebugVerbose {
                        logger.verbose("Gaze batch sent successfully")
                    }
                } else {
                    gazeEvents.append(contentsOf: eventsBeingSent)
                    logger.warning("Failed to send gaze batch - events restored")
                }
            } catch let error {
                logger.error("Error sending gaze batch: \(error)")

                if core.isNetworkError(error) {
                    logger.info("Network error detected, storing gaze data in cache")

                    // Store in persistent cache for network errors
                    if let dataCache = core.dataCacheSystem {
                        if let gazeData = try? JSONEncoder().encode(gaze) {
                            Task {
                                let sceneId = core.getCurrentSceneId()
                                let version = core.getCurrentSceneVersionNumber()

                                guard
                                    let url = NetworkEnvironment.current.constructGazeURL(
                                        sceneId: sceneId,
                                        version: version
                                    )
                                else {
                                    logger.error("Failed to create URL for gaze data")
                                    return
                                }
                                await dataCache.cacheRequest(url: url, body: gazeData)
                                logger.verbose("Successfully cached gaze data for later transmission")
                            }
                        } else {
                            logger.error("Failed to encode gaze data for caching")
                        }
                    } else {
                        logger.warning("DataCacheSystem not available - unable to cache gaze data")
                    }
                }
            }

            isSending = false
        }

        return gaze
    }

    /// Post to the back end the mandatory session properties using an empty  Gaze event.
    @discardableResult internal func sendMandatoryData() -> Gaze? {
        guard !isSending, let core = core else {
            logger.verbose("Send already in progress.")
            return nil
        }

        isSending = true
        // We don't need to include any gazes for this post.
        let eventsBeingSent: [GazeEventData] = []
        gazeEvents.removeAll()

        // Get device properties struct, then convert to dictionary
        var sessionProperties = createDeviceProperties(core: core).toDictionary()
        // Merge any new session properties with the device properties
        let newSessionProperties = core.getNewSessionProperties(clear: true)
        sessionProperties = sessionProperties.merging(newSessionProperties) { (_, new) in new }

        let gaze = Gaze(
            userId: core.getUserId(),
            timestamp: Date().timeIntervalSince1970,
            sessionId: core.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            hmdType: visonProHmdType,
            interval: sendInterval,
            properties: sessionProperties,
            data: eventsBeingSent
        )

        Task {
            do {
                if isBodyDebugEnabled {
                    logGazeBody(gaze: gaze)
                }

                let response: GazeResponse = try await networkClient.makeRequest(
                    endpoint: "gaze",
                    sceneId: core.getCurrentSceneId(),
                    version: String(core.getCurrentSceneVersionNumber()),
                    method: .post,
                    body: gaze
                )

                if response.received {
                    jsonPart += 1
                    if isDebugVerbose {
                        logger.verbose("Gaze batch sent successfully")
                    }
                } else {
                    gazeEvents.append(contentsOf: eventsBeingSent)
                    logger.warning("Failed to send gaze batch")
                }
            } catch let error {
                logger.error("Error sending mandatory data (gaze): \(error)")

                // Check if it's a network error
                if core.isNetworkError(error) {
                    logger.info("Network error detected, storing mandatory data in cache")

                    // Store in persistent cache for network errors
                    if let dataCache = core.dataCacheSystem {
                        if let gazeData = try? JSONEncoder().encode(gaze) {
                            Task {
                                let sceneId = core.getCurrentSceneId()
                                let version = core.getCurrentSceneVersionNumber()
                                guard
                                    let url = NetworkEnvironment.current.constructGazeURL(
                                        sceneId: sceneId,
                                        version: version
                                    )
                                else {
                                    logger.error("Failed to create URL for gaze data")
                                    return
                                }

                                await dataCache.cacheRequest(url: url, body: gazeData)
                                logger.verbose("Successfully cached gaze data for later transmission")
                            }
                        } else {
                            logger.error("Failed to encode gaze data for caching")
                        }
                    } else {
                        logger.warning("DataCacheSystem not available - unable to cache gaze data")
                    }
                }
            }

            isSending = false
        }

        return gaze
    }

    // MARK: - Debug code
    /// Log the the JSON body for debugging purposes
    private func logGazeBody(gaze: Gaze) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let jsonData = try encoder.encode(gaze)
            if isDebugVerbose {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    logger.verbose("Full Request Body:")
                    logger.verbose(jsonString)
                }
            } else {
                truncatedBodyDebug(jsonData: jsonData)
            }
        } catch {
            logger.error("Failed to encode gaze data: \(error)")
        }
    }

    /// print out the JSON body but transform the data array to only show the first 2 entries
    func truncatedBodyDebug(jsonData: Data) {
        guard let jsonObj = try? JSONSerialization.jsonObject(with: jsonData),
            let jsonDict = jsonObj as? [String: Any]
        else {
            logger.error("Failed to parse JSON object")
            return
        }

        var mutableDict = jsonDict

        if let dataArray = mutableDict["data"] as? [[String: Any]] {
            let maxEntries = 2
            let truncatedData = Array(dataArray.prefix(maxEntries))

            if dataArray.count > maxEntries {
                let remainingCount = dataArray.count - maxEntries
                let ellipsis: [String: Any] = [
                    "...": "(truncated \(remainingCount) more entries)"
                ]
                mutableDict["data"] = truncatedData + [ellipsis]
            } else {
                mutableDict["data"] = truncatedData
            }
        }

        do {
            let limitedData = try JSONSerialization.data(
                withJSONObject: mutableDict,
                options: [.prettyPrinted]
            )

            if let limitedString = String(data: limitedData, encoding: .utf8) {
                logger.info("Truncated Request Body:")
                logger.info(limitedString)
            }
        } catch {
            logger.error("Failed to serialize truncated JSON: \(error)")
        }
    }

    // MARK: - Session Management
    func endSession() {

        // TODO: handle errors
        _ = sendData()
        gazeEvents.removeAll()
        jsonPart += 1
    }

    private var coordSystem: CoordinateSystem {
        return core?.getConfig().targetCoordinateSystem ?? .leftHanded
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
