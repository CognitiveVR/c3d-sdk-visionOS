//
//  YawRecorder.swift
//  Cognitive3D-Analytics-core
//

import QuartzCore
import SwiftUI

/// Sensor recorder for the HMD yaw (rotation around the vertical/Y axis).
/// This class works with the internal ``ARSessionManager`` class using the ``ARSessionDelegate``
/// to get world orientation information for the HMD transform.
public class YawRecorder: ARSessionDelegate {
    private let sensorRecorder: SensorRecorder
    private var lastRecordTime: CFTimeInterval = 0
    private let updateInterval: TimeInterval
    private var isTracking = false

    /// Initializes a new YawRecorder instance
    /// - Parameters:
    ///   - sensorRecorder: The SensorRecorder instance to use for recording yaw data
    ///   - updateInterval: How frequently to record yaw values, in seconds (defaults to 1.0)
    public init(sensorRecorder: SensorRecorder, updateInterval: TimeInterval = 1.0) {
        self.sensorRecorder = sensorRecorder
        self.updateInterval = updateInterval
    }

    deinit {
        stop()
    }

    /// Begins tracking the HMD yaw
    /// Registers with ARSessionManager as a delegate to receive transform updates
    public func startTracking() {
        guard !isTracking else { return }

        isTracking = true
        ARSessionManager.shared.addDelegate(self)
    }

    /// Ends the tracking session and cleans up resources
    public func endSession() {
        stop()
    }

    /// Stops tracking the HMD yaw
    /// Unregisters from ARSessionManager as a delegate
    public func stop() {
        isTracking = false
        ARSessionManager.shared.removeDelegate(self)
    }

    // MARK: - ARSessionDelegate Methods

    /// Processes device transform updates from ARSessionManager
    /// Calculates the yaw angle and records it using the SensorRecorder
    /// - Parameter transform: The current device transform matrix
    public func arSessionDidUpdateTransform(_ transform: simd_float4x4) {
        guard isTracking else { return }

        // Check if enough time has passed since the last recording
        let currentTime = CACurrentMediaTime()
        guard (currentTime - lastRecordTime) >= updateInterval else { return }

        // Extract basis vectors from the transform matrix
        // The right vector is the x-axis of the transform
        let rightVector = simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)

        // The forward vector is the negative z-axis of the transform
        // (negative because in OpenGL/ARKit, forward is -Z)
        let forwardVector = simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)

        // Project the forward vector onto the horizontal (XZ) plane for yaw calculation
        // This ignores any pitch component and gives us only the yaw rotation
        let forwardXZ = simd_normalize(simd_float3(forwardVector.x, 0, forwardVector.z))

        // Define the world forward vector (positive Z-axis in world space)
        let worldForward = simd_float3(0, 0, 1)

        // Calculate the angle between the projected forward vector and world forward
        // The dot product of normalized vectors gives us the cosine of the angle
        var yawRadians = acos(simd_dot(forwardXZ, worldForward))

        // Determine the sign of the yaw angle
        // If the right vector's Z component is negative, we're rotated to the left (counterclockwise)
        // This handles the full 360-degree range of yaw values
        if simd_dot(rightVector, worldForward) < 0 {
            yawRadians = -yawRadians
        }

        // Convert radians to degrees and round to one decimal place for readability
        let yawDegrees = yawRadians * 180 / .pi
        let roundedYaw = round(yawDegrees * 10) / 10

        // Record the yaw value through the sensor recorder
        sensorRecorder.recordDataPoint(name: "c3d.hmd.yaw", value: Double(roundedYaw))
        lastRecordTime = currentTime
    }
}
