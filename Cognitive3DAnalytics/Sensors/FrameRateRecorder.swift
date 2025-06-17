//
//  FrameRateRecorder.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Combine
import SwiftUI

/// This class determines the current frame rate of the application.
/// It can be used with the C3D and with user application code when the sensor recorder is not provided - see various init methods.
public class FrameRateRecorder: ObservableObject {
    // MARK: - Properties
    @Published public private(set) var fps: Double = 0
    @Published public private(set) var low5Percent: Double = 0
    @Published public private(set) var low1Percent: Double = 0

    // Array of [timestamp, frameTime] pairs
    private var frameTimes: [[Double]] = []

    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var isTracking = false

    // sensor recorder for analytics
    private let sensorRecorder: SensorRecorder?

    // Configurable update interval
    private let updateInterval: TimeInterval

    // MARK: - Initialization

    // UI-only initializer with optional update interval
    public init(updateInterval: TimeInterval = 1.0) {
        self.sensorRecorder = nil
        self.updateInterval = updateInterval
    }

    // Analytics initializer with optional update interval
    public init(sensorRecorder: SensorRecorder, updateInterval: TimeInterval = 1.0) {
        self.sensorRecorder = sensorRecorder
        self.updateInterval = updateInterval
    }

    // MARK: - Tracking Methods
    public func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        setupDisplayLink()
    }

    /// The display link is used to synchronize the app's drawing to the refresh rate of the display.
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleFrame))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = CACurrentMediaTime()  // Reset timestamp when starting
    }

    /// Calculate the frame rate
    @objc private func handleFrame(displayLink: CADisplayLink) {
        guard isTracking else { return }

        let currentTime = displayLink.timestamp
        frameCount += 1

        let frameTime = displayLink.targetTimestamp - displayLink.timestamp
        frameTimes.append([displayLink.timestamp, frameTime])

        let elapsed = currentTime - lastTimestamp
        if elapsed >= updateInterval {
            let currentFPS = Double(frameCount) / elapsed
            let roundedFPS = round(currentFPS)

            // Calculate lower percent metrics
            let metrics = calculateLowerPercentMetrics()

            // Update UI if being used for display
            DispatchQueue.main.async {
                self.fps = roundedFPS
                self.low5Percent = metrics.low5Percent
                self.low1Percent = metrics.low1Percent
            }

            // Record analytics if sensor recorder is available
            if let sensorRecorder = sensorRecorder {
                sensorRecorder.recordDataPoint(name: "c3d.fps.avg", value: roundedFPS)
                sensorRecorder.recordDataPoint(name: "c3d.fps.5pl", value: metrics.low5Percent)
                sensorRecorder.recordDataPoint(name: "c3d.fps.1pl", value: metrics.low1Percent)
            }

            // Reset the frame count and timestamps
            frameCount = 0
            lastTimestamp = currentTime
            frameTimes.removeAll()
        }
    }

    private func calculateLowerPercentMetrics() -> (low5Percent: Double, low1Percent: Double) {
        guard !frameTimes.isEmpty else { return (0, 0) }

        let sortedTimes = frameTimes.sorted { $0[1] > $1[1] }  // Sort by frame time (index 1) in descending order

        // Calculate sample sizes
        let count5Percent = Int(ceil(Double(frameTimes.count) * 0.05))
        let count1Percent = Int(ceil(Double(frameTimes.count) * 0.01))

        // Calculate totals for each percentage
        let total5Percent = sortedTimes.prefix(count5Percent).reduce(0.0) { $0 + $1[1] }
        let total1Percent = sortedTimes.prefix(count1Percent).reduce(0.0) { $0 + $1[1] }

        // Calculate averages and convert to FPS
        let avg5Percent = total5Percent / Double(count5Percent)
        let avg1Percent = total1Percent / Double(count1Percent)

        let low5Percent = round(1.0 / avg5Percent)
        let low1Percent = round(1.0 / avg1Percent)

        return (low5Percent, low1Percent)
    }

    // MARK: - Session Management
    public func endSession() {
        stop()
    }

    public func stop() {
        isTracking = false
        displayLink?.invalidate()
        displayLink = nil
        frameCount = 0
        lastTimestamp = 0
    }

    deinit {
        stop()
    }
}
