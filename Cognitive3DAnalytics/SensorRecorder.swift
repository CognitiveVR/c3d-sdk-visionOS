//
//  SensorRecorder.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The `SensorRecorder` class is used to record data from various sources; the recorder works with internal sensors and custom sensors created by application developers.
/// Data is recorded as a key/value pair including a unix timestamp.
/// A sensor reading has a name (key) & an associated numeric value.
/// E.g "heart rate" : 160
public class SensorRecorder {
    // MARK: - Properties
    internal var cvr: Cognitive3DAnalyticsCore
    private var batchedSensorData: [String: [[Double]]] = [:]
    private var jsonPart = 1
    private let networkClient: NetworkAPIClient
    private let sceneData: SceneData
    private let logger: CognitiveLog
    private var isSending = false
    private var pendingTasks: Set<Task<Sensor?, Never>> = []
    private var lastSensorValues: [String: (value: Double, timestamp: TimeInterval)] = [:]
    private let sensorValueChangeThreshold: Double = 0.001
    private let minFrequencyKeepAliveSignal: TimeInterval = 2.0
    public var filteringEnabled: Bool = true

    private var sendTimer: Timer?
    private var autoSendInterval: TimeInterval = 2.0  // 2 seconds (configurable)
    private var lastSendTime: TimeInterval = -60.0  // Track last send time

    /// Sensors can produce a lot of data as they are being updated frequently - this property is used to control the amount of verbose logging.
    private var verboseLogLevel = 2

    // Serial queue for synchronizing access to shared state
    private let queue = DispatchQueue(label: "com.cognitive3d.sensorrecorder")

    // MARK: - Initialization
    public init(cog: Cognitive3DAnalyticsCore, sceneData: SceneData) {
        cvr = cog
        self.sceneData = sceneData

        let config = cog.getConfig()
        networkClient = NetworkAPIClient(apiKey: config.applicationKey, cog: cog)
        logger = CognitiveLog(category: "SensorRecorder")
        logger.isDebugVerbose = true

        // Inherit log level from core
        if let coreLogger = cog.getLog() {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }

        // Get the configurable timer interval
        autoSendInterval = config.sensorAutoSendInterval
    }

    deinit {
        sendTimer?.invalidate()
        queue.sync {
            pendingTasks.forEach { $0.cancel() }
        }
    }

    // MARK: -
    private func setupAutoSendTimer() {
        logger.verbose("Setting up auto-send timer with interval: \(autoSendInterval) seconds")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sendTimer?.invalidate()
            self.sendTimer = Timer(timeInterval: self.autoSendInterval, repeats: true) { [weak self] timer in
                self?.logger.verbose("Auto-send timer triggered - timer is valid: \(timer.isValid)")
                Task {
                    await self?.sendData()
                }
            }
            if let timer = self.sendTimer {
                RunLoop.main.add(timer, forMode: .common)
                self.logger.verbose("Timer added to RunLoop.main in .common mode")
            }
        }
    }

    internal func startSessionTimer() {
        setupAutoSendTimer()
    }

    internal func stopSessionTimer() {
        sendTimer?.invalidate()
        sendTimer = nil
    }

    // MARK: - Public Methods
    /// Records a single data point for a sensor.
    /// - Parameters:
    ///   - name: The name of the sensor (e.g., "c3d.hmd.yaw", "c3d.fps.avg")
    ///   - value: The sensor value to record
    /// - Returns: `true` if the data point was accepted for recording, `false` if skipped due to filtering or if the session is not active
    /// - Note: When filtering is enabled (default), data points may be skipped if:
    ///     1. The value hasn't changed significantly (< 0.001) from the previously recorded value AND
    ///     2. The minimum keep-alive interval (2.0 seconds) hasn't elapsed since the last recording
    @discardableResult public func recordDataPoint(name: String, value: Double) -> Bool {
        guard cvr.isSessionActive else {
            return false
        }

        let currentTime = Date().timeIntervalSince1970

        // Apply filtering if enabled
        if filteringEnabled {
            // Check if we have recorded this sensor before
            if let (lastValue, lastTime) = lastSensorValues[name] {
                // Only record if value changed significantly OR enough time has passed
                let significantChange = abs(lastValue - value) >= sensorValueChangeThreshold
                let timeThresholdMet = (currentTime - lastTime) >= minFrequencyKeepAliveSignal

                if !significantChange && !timeThresholdMet {
                    // Skip recording - change not significant and not time for keep-alive
                    return false
                }
            }

            // Update the last recorded value and time
            lastSensorValues[name] = (value, currentTime)
        }

        #if DEBUG && DEBUG_SENSORS
            logger.formatSensor(name: name, value: value, timestamp: cvr.getTimestamp())
        #endif

        let reading: [Double] = [cvr.getTimestamp(), value]
        var shouldSendData = false

        shouldSendData = queue.sync {
            if batchedSensorData[name] == nil {
                batchedSensorData[name] = []
            }
            batchedSensorData[name]?.append(reading)

            let config = cvr.getConfig()
            return (batchedSensorData[name]?.count ?? 0) >= config.customEventBatchSize
        }

        if shouldSendData {
            logger.verbose("Batch size reached for sensor \(name). Sending data...")
            let task = Task { [weak self] in
                await self?.sendData()
            }
            let _ = queue.sync {
                pendingTasks.insert(task)
            }
        }

        return true
    }

    // MARK: - Internal Methods
    @discardableResult
    internal func sendData() async -> Sensor? {
        logger.verbose("sendData() called - checking if data available to send")

        // Prepare data for sending
        let (shouldSend, localData, sensor) = prepareDataForSending()

        guard shouldSend, let sensor = sensor else {
            logger.verbose("No sensor data to send.")
            return nil
        }

        logger.verbose("Sending sensor data batch with \(localData.count) sensor types")

        // Send data to server
        do {
            let response = try await sendSensorDataToServer(sensor)

            queue.sync {
                if response.received {
                    jsonPart += 1
                    lastSendTime = Date().timeIntervalSince1970  // Track send time
                    logger.verbose("Successfully sent sensor data batch (part \(jsonPart-1)) at time \(lastSendTime)")

                } else {
                    // Merge back the unsent data
                    mergeSensorDataBack(localData)
                    logger.warning("Server did not acknowledge sensor data receipt")
                }
                isSending = false
            }
        } catch let error {
            queue.sync {
                isSending = false
            }

            // Handle errors
            await handleSendError(error, sensor, localData)
        }

        return sensor
    }

    // MARK: - Helper Methods

    private func prepareDataForSending() -> (shouldSend: Bool, localData: [String: [[Double]]], sensor: Sensor?) {
        var shouldSend = false
        var localData: [String: [[Double]]] = [:]

        queue.sync {
            guard !isSending && !batchedSensorData.isEmpty else { return }
            shouldSend = true
            isSending = true
            localData = batchedSensorData
            batchedSensorData.removeAll()
        }

        #if DEBUG
            logger.info("Batch sensors with count: \(localData.count)")
        #endif

        guard shouldSend else {
            if verboseLogLevel > 1 {
                logger.verbose("No sensor data to send.")
            }

            return (false, [:], nil)
        }

        let sensorDataArray = localData.map { name, readings in
            SensorEventData(name: name, data: readings)
        }

        let sensor = Sensor(
            userId: cvr.getUserId(),
            timestamp: cvr.getSessionTimestamp(),
            sessionId: cvr.getSessionId(),
            part: jsonPart,
            formatVersion: analyticsFormatVersion1,
            sessionType: "sensor",
            data: sensorDataArray
        )

        return (true, localData, sensor)
    }

    private func sendSensorDataToServer(_ sensor: Sensor) async throws -> EventResponse {
        return try await networkClient.makeRequest(
            endpoint: "sensors",
            sceneId: sceneData.sceneId,
            version: String(sceneData.versionNumber),
            method: .post,
            body: sensor
        )
    }

    private func handleSendError(_ error: Error, _ sensor: Sensor, _ localData: [String: [[Double]]]) async {
        // Handle network errors by caching
        if cvr.isNetworkError(error) {
            logger.info("Network error detected, caching sensor data")
            await cacheSensorData(sensor)
        } else {
            // For non-network errors, merge data back to memory
            queue.sync {
                mergeSensorDataBack(localData)
            }
            logger.error("Error sending sensor data batch: \(error)")
        }
    }

    private func mergeSensorDataBack(_ dataToMerge: [String: [[Double]]]) {
        for (key, value) in dataToMerge {
            if batchedSensorData[key] == nil {
                batchedSensorData[key] = value
            } else {
                batchedSensorData[key]?.append(contentsOf: value)
            }
        }
    }

    private func cacheSensorData(_ sensor: Sensor) async {
        guard let dataCache = cvr.dataCacheSystem else {
            logger.warning("DataCacheSystem not available - unable to cache sensor data")
            return
        }

        do {
            let sensorData = try JSONEncoder().encode(sensor)

            let sceneId = sceneData.sceneId
            let version = sceneData.versionNumber
            guard let url = NetworkEnvironment.current.constructSensorsURL(sceneId: sceneId, version: version) else {
                logger.error("Failed to create URL for sensor data")
                return
            }

            // Cache the data for later transmission
            await dataCache.cacheRequest(url: url, body: sensorData)
            logger.info("Successfully cached sensor data for later transmission")
        } catch {
            logger.error("Failed to encode sensor data for caching: \(error)")
        }
    }

    public func endSession() async {
        logger.verbose("Sensor recorder: ending session")
        var hasData = false
        queue.sync { hasData = !batchedSensorData.isEmpty }

        if hasData {
            logger.verbose("Processing remaining sensor data")
            await sendData()
        }

        queue.sync {
            pendingTasks.forEach { $0.cancel() }
            pendingTasks.removeAll()
            batchedSensorData.removeAll()
        }

        // Stop the auto-send timer
        sendTimer?.invalidate()
        sendTimer = nil
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
