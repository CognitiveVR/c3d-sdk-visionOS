//
//  GazeRecorder.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import ARKit
import Foundation
import Observation
import QuartzCore
import RealityKit

public enum GazeRecorderError: Error {
    case noDataAvailable
    case sendFailed
}

public protocol GazeRecorderDelegate: AnyObject {
    func gazeTrackerDidUpdate(_ data: GazeEventData)
}

/// The `GazeRecorder` is one of the primary recorders in the C3D analytics SDK.  It records where the HMD is currently looking using world tracking with an `ARSession`.
/// See also the class ``ARSessionManager``.
@Observable public class GazeRecorder {
    // MARK: - Properties
    private let dataManager: GazeDataManager
    private let core: Cognitive3DAnalyticsCore
    private let logger = CognitiveLog(category: "GazeRecorder")
    private let config: Config
    public weak var delegate: GazeRecorderDelegate?
    private var isTracking = false

    /// Logging metrics
    private var lastLogTime: TimeInterval = 0
    private var lastDebugTime: TimeInterval = 0
    private var updateCount: Int = 0

    /// local override for debugging, setting this to true can produce a signifcant amount of debug
    private let isDebugVerbose = false
    private let logInterval: TimeInterval = 10.0  // Log stats every 10 seconda

    // We only want to report this once.
    private var hasLoggedWarning = false

    // Convert gazeInterval to Double for consistent timing calculations
    private var gazeIntervalSeconds: TimeInterval {
        TimeInterval(config.gazeInterval)
    }

    /// ARKit tracking
    // TODO: use a single AR Kit session in the analytics SDK
    private let session = ARKitSession()

    /// The world tracking provider gets queried to get the positional data for the world anchor for the headset.
    private let worldTracking = WorldTrackingProvider()

    // Task handle for continuous tracking
    private var trackingTask: Task<Void, Error>?

    // MARK: - Initialization
    public init(core: Cognitive3DAnalyticsCore) {
        self.core = core
        self.config = core.getConfig()
        self.dataManager = GazeDataManager(core: core)

        if let coreLogger = core.logger {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }
    }

    deinit {
        stopTracking()
    }

    // MARK: - Public Methods
    /// This method is called to start gaze tracking.
    public func startTracking() async {
        guard !isTracking else {
            logger.warning("GazeTracker: Tracking already active - ignoring start request")
            return
        }

        do {
            try await session.run([worldTracking])
            logger.verbose("ARKit session started successfully")
            isTracking = true
            lastLogTime = Date().timeIntervalSince1970
            lastDebugTime = lastLogTime
            updateCount = 0

            trackingTask = Task {
                await startContinuousTracking()
            }
        } catch {
            logger.error("Failed to start ARKit session: \(error.localizedDescription)")
        }
    }

    /// Send the recorded gaze records to the back end.
    public func sendData() async throws -> [String: Any] {
        guard let gazeData = dataManager.sendData() else {
            throw GazeRecorderError.noDataAvailable
        }

        return [
            "userId": gazeData.userId,
            "timestamp": gazeData.timestamp,
            "sessionId": gazeData.sessionId,
            "part": gazeData.part,
            "interval": gazeData.interval,
            "formatVersion": gazeData.formatVersion,
        ]
    }

    public func sendMandatoryData() async throws -> [String: Any] {
        guard let gazeData = dataManager.sendMandatoryData() else {
            throw GazeRecorderError.sendFailed
        }

        return [
            "userId": gazeData.userId,
            "timestamp": gazeData.timestamp,
            "sessionId": gazeData.sessionId,
            "part": gazeData.part,
            "interval": gazeData.interval,
            "formatVersion": gazeData.formatVersion,
        ]
    }

    /// Stop gaze tracking.
    public func stopTracking() {
        if isTracking {
            logger.info("Stopping tracking - Final stats: Processed \(updateCount) updates")
            isTracking = false
            trackingTask?.cancel()
            trackingTask = nil
        }
    }

    public func endSession() {
        stopTracking()
        dataManager.endSession()
        logger.verbose("GazeTracker endSession")
    }

    // MARK: - Private Methods

    /// Represents the result of a collision check between a gaze ray and a dynamic object in the scene
    private struct CollisionResult {
        /// The unique identifier of the object that was hit
        let objectId: String
        /// The hit point in local space coordinates, converted to the target coordinate system
        let gazePoint: [Double]
    }

    /// Update the tracking in the scene & record gazes. If a collision with a dynamic object is detected,
    /// records the gaze with object information. Otherwise, records a basic gaze event.
    private func updateTrackingAndRecordGazes() async {
        let deviceTransform = await getDeviceTransform()
        let trackingData = extractTrackingData(from: deviceTransform, timestamp: Date().timeIntervalSince1970)

        if let scene = await core.entity?.scene {
            if !hasLoggedWarning {
                logger.verbose("collision check using raycast length of \(config.raycastLength)")
                hasLoggedWarning = true
            }

            if let collision = checkCollision(scene: scene, deviceTransform: deviceTransform) {
                #if DEBUG_GAZES
                logger.verbose("collision with \(collision.objectId)")
                #endif
                let newData = GazeEventData(
                    time: trackingData.time,
                    floorPosition: trackingData.floorPosition,
                    gazePoint: collision.gazePoint,
                    headPosition: trackingData.headPosition,
                    headRotation: trackingData.headRotation,
                    objectId: collision.objectId
                )
                dataManager.recordGaze(newData)
                delegate?.gazeTrackerDidUpdate(newData)

                // Notify gaze sync
                await core.gazeSyncManager.notifyGazeTick()
                return
            }

            dataManager.recordGaze(trackingData)
            delegate?.gazeTrackerDidUpdate(trackingData)

            // Notify gaze sync
            await core.gazeSyncManager.notifyGazeTick()
        } else {
            dataManager.recordGaze(trackingData)
            delegate?.gazeTrackerDidUpdate(trackingData)

            if !hasLoggedWarning {
                logger.warning("Gaze tracking & ray casts: scene is not available yet.\nThe RealityView contents may not be fully loaded yet.")
                hasLoggedWarning = true
            }
        }
    }

    /// Create a raycast based on the gaze and check for collision hits in the scene.
    /// Returns collision information if a hit is found with a dynamic object.
    /// - Parameters:
    ///     - scene: The RealityKit.Scene instance in which raycast results are checked
    ///     - deviceTransform: The device's current transformation matrix, which provides position and direction
    /// - Returns: CollisionResult containing the hit object's ID and local space position if a hit with
    ///           a dynamic object is found, nil otherwise
    private func checkCollision(scene: Scene, deviceTransform: simd_float4x4) -> CollisionResult? {
        let hits = scene.raycast(
            origin: deviceTransform.position,
            direction: simd_normalize(deviceTransform.forward),
            length: config.raycastLength
        )

        guard let firstHit = hits.first,
            let objectId = getDynamicId(from: firstHit.entity)
        else {
            return nil
        }

        let hitEntity = firstHit.entity

        // Get the inverse of the entity's transform to convert to local space
        let worldToLocalTransform = hitEntity.transform.matrix.inverse

        // Convert world-space hit position to local space
        let worldPosition = simd_float4(firstHit.position.x, firstHit.position.y, firstHit.position.z, 1)
        let localPosition = worldToLocalTransform * worldPosition

        // Convert to array format for coordinate system conversion
        let localGazePoint = [
            Double(localPosition.x),
            Double(localPosition.y),
            Double(localPosition.z),
        ]

        let gazePoint = core.getConfig()
            .targetCoordinateSystem
            .convertPosition(localGazePoint)

        return CollisionResult(objectId: objectId, gazePoint: gazePoint)
    }
    /// Record a gaze which has hit an dynamic object in the scene.
    private func recordGazeWithObject(_ trackingData: GazeEventData, _ gazePoint: [Double], _ objectId: String) {
        let newData = GazeEventData(
            time: trackingData.time,
            floorPosition: trackingData.floorPosition,
            gazePoint: gazePoint,
            headPosition: trackingData.headPosition,
            headRotation: trackingData.headRotation,
            objectId: objectId
        )

        logger.verbose("raycast hit entity with dynamic object id: \(objectId)")

        dataManager.recordGaze(newData)
    }

    /// The Dynamic component class is declared outside the framework, hence the need for using reflection.
    private func getDynamicId(from entity: Entity) -> String? {
        for component in entity.components {
            let componentName = String(describing: type(of: component))
            if componentName == "DynamicComponent" {
                if let dynamicId = Mirror(reflecting: component).children.first(where: { $0.label == "dynamicId" })?
                    .value as? String
                {
                    return dynamicId
                }
            }
        }
        return nil
    }

    /// Get the positional information from the tracking system transform.
    /// The position vectors get converted to arrays for JSON serialization.
    /// Note: the data may be converted to a different coordinate system.
    private func extractTrackingData(from transform: simd_float4x4, timestamp: TimeInterval) -> GazeEventData {
        let position = transform.position
        let quaternion = simd_quaternion(transform.rotationMatrix)

        // Floor position is directly below the HMD at y=0 (floor level)
        let floorPosition = SIMD3<Float>(position.x, 0, position.z)

        // Calculate gaze direction using the forward vector from transform
        let gazeDirection = transform.forward
        let gazeDistance: Float = 1.0  // 1 meter length
        let gazePoint = position + (gazeDirection * gazeDistance)

        // Convert quaternion components to array
        let rotationArray = [
            Double(quaternion.vector.x),
            Double(quaternion.vector.y),
            Double(quaternion.vector.z),
            Double(quaternion.real),
        ]

        let coordSystem = core.getConfig().targetCoordinateSystem

        return GazeEventData(
            time: timestamp,
            floorPosition: coordSystem.convertPosition(floorPosition.toDouble()),
            gazePoint: coordSystem.convertPosition(gazePoint.toDouble()),
            headPosition: coordSystem.convertPosition(position.toDouble()),
            headRotation: coordSystem.convertRotation(rotationArray),
            objectId: nil
        )
    }

    private func getDeviceTransform() async -> simd_float4x4 {
        guard worldTracking.state == .running,
            let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        else {
            return .init()
        }
        return deviceAnchor.originFromAnchorTransform
    }

    private func startContinuousTracking() async {
        logger.info(
            "🌐 Starting continuous tracking - interval: \(String(format: "%.1f", gazeIntervalSeconds))s (ARKit session started)"
        )

        var hasLoggedTrackingWarning = false

        while isTracking && !Task.isCancelled {
            let updateStart = Date().timeIntervalSince1970

            guard worldTracking.state == .running else {
                if !hasLoggedTrackingWarning {
                    logger.warning("🌐 World tracking is not running - waiting for immersive mode")
                    hasLoggedTrackingWarning = true
                }
                try? await Task.sleep(for: .seconds(0.5))
                continue
            }

            if hasLoggedTrackingWarning {
                logger.info("🌐 World tracking has resumed running")
            }

            hasLoggedTrackingWarning = false

            await updateTrackingAndRecordGazes()
            updateCount += 1

            if isDebugVerbose {
                logPerformanceMetrics()
            }

            let updateDuration = Date().timeIntervalSince1970 - updateStart
            let sleepDuration = max(0, gazeIntervalSeconds - updateDuration)
            try? await Task.sleep(for: .seconds(sleepDuration))
        }

        logger.info("🌐 Continuous tracking stopped")
    }

    private func logDebugInfo(_ data: GazeEventData) {
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastDebugTime >= 1.0 {
            logger.info(
                """
                Gaze Update:
                \(Utils.prettyPrintPosition(data.headPosition))
                \(Utils.prettyPrintPosition(data.gazePoint))
                Floor: \(Utils.prettyPrintPosition(data.floorPosition))
                """
            )
            lastDebugTime = currentTime
        }
    }

    private func logPerformanceMetrics() {
        let currentTime = Date().timeIntervalSince1970
        let elapsedTime = currentTime - lastLogTime

        if elapsedTime >= logInterval {
            let updatesPerSecond = Double(updateCount) / elapsedTime
            logger.info(
                "Performance: \(String(format: "%.1f", updatesPerSecond)) updates/sec (Expected: \(String(format: "%.1f", 1.0/gazeIntervalSeconds)) updates/sec)"
            )
            updateCount = 0
            lastLogTime = currentTime
        }
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
