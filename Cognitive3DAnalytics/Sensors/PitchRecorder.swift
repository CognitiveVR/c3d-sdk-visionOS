//
//  PitchRecorder.swift
//  Cognitive3D-Analytics-core
//

import QuartzCore
import SwiftUI

/// Sensor recorder for the HMD pitch (rotation around the horizontal/X axis).
/// This class works with the internal ``ARSessionManager`` class using the ``ARSessionDelegate``
/// to get world orientation information for the HMD transform.
public class PitchRecorder: ARSessionDelegate {
    private let sensorRecorder: SensorRecorder
    private var lastRecordTime: CFTimeInterval = 0
    private let updateInterval: TimeInterval
    private var isTracking = false

    /// Initializes a new PitchRecorder instance
    /// - Parameters:
    ///   - sensorRecorder: The SensorRecorder instance to use for recording pitch data
    ///   - updateInterval: How frequently to record pitch values, in seconds (defaults to 1.0)
    public init(sensorRecorder: SensorRecorder, updateInterval: TimeInterval = 1.0) {
        self.sensorRecorder = sensorRecorder
        self.updateInterval = updateInterval
    }

    deinit {
        stop()
    }

    /// Begins tracking the HMD pitch
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

    /// Stops tracking the HMD pitch
    /// Unregisters from ARSessionManager as a delegate
    public func stop() {
        isTracking = false
        ARSessionManager.shared.removeDelegate(self)
    }

    // MARK: - ARSessionDelegate Methods

    /// Processes device transform updates from ARSessionManager
    /// Calculates the pitch angle and records it using the SensorRecorder
    /// - Parameter transform: The current device transform matrix
    public func arSessionDidUpdateTransform(_ transform: simd_float4x4) {
        guard isTracking else { return }

        // Check if enough time has passed since the last recording
        let currentTime = CACurrentMediaTime()
        guard (currentTime - lastRecordTime) >= updateInterval else { return }

        // Get the forward vector (negative z-axis of the transform)
        // In OpenGL/ARKit coordinate systems, forward is -Z
        let forwardVector = simd_float3(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)

        // Calculate pitch (rotation around x-axis)
        // Pitch is the elevation angle, which can be found by taking the
        // arc sine of the y-component of the forward vector
        // This gives us the angle between the forward vector and the horizontal plane
        let pitchRadians = asin(forwardVector.y)

        // Convert from radians to degrees for easier interpretation
        let pitchDegrees = pitchRadians * 180 / .pi

        // Round to 1 decimal place for readability and to reduce noise
        let roundedPitch = round(pitchDegrees * 10) / 10

        // Record the pitch value through the sensor recorder
        sensorRecorder.recordDataPoint(name: "c3d.hmd.pitch", value: Double(roundedPitch))
        lastRecordTime = currentTime
    }
}
