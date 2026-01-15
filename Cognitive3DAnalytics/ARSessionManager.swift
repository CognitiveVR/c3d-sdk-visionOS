//
//  ARSessionManager.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import ARKit
import QuartzCore

/// Protocol for getting AR session data for the HMD device.
@objc public protocol ARSessionDelegate: AnyObject {

    /// Get the latest position of the HMD.
    @objc optional func arSessionDidUpdatePosition(_ position: [Double])

    /// Get the transform for the HMD.
    @objc optional func arSessionDidUpdateTransform(_ transform: simd_float4x4)
}

/// Centralized AR session manager providing world tracking for the HMD.
/// This singleton manages a single ARKit session shared across the SDK to avoid
/// resource conflicts and duplicate sessions.
public class ARSessionManager {
    // MARK: - Properties
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let logger = CognitiveLog(category: "ARSessionManager")
    private var isTracking = false
    private var delegates: [ARSessionDelegate] = []

    // MARK: - Singleton
    public static let shared = ARSessionManager()

    public var isTrackingActive: Bool {
        return isTracking
    }

    /// Returns the current state of the world tracking provider
    public var worldTrackingState: DataProviderState{
        return worldTracking.state
    }

    private init() {}

    // MARK: - Delegate Management
    public func addDelegate(_ delegate: ARSessionDelegate) {
        // Avoid duplicate delegate registrations
        if !delegates.contains(where: { $0 === delegate }) {
            delegates.append(delegate)
        }
    }

    public func removeDelegate(_ delegate: ARSessionDelegate) {
        delegates.removeAll { $0 === delegate }
    }

    // MARK: - Session Management
    public func startTracking() async {
        guard !isTracking else {
            logger.warning("Tracking already active")
            return
        }

        do {
            try await session.run([worldTracking])
            isTracking = true
            logger.verbose("ARKit session started successfully")
            startUpdates()
        } catch {
            logger.error("Failed to start ARKit session: \(error.localizedDescription)")
        }
    }

    public func stopTracking() {
        isTracking = false
    }

    // MARK: - Position Updates
    private func startUpdates() {
        Task {
            while isTracking && !Task.isCancelled {
                if let transform = getTransform() {
                    let position = transform.position.toDouble()
                    for delegate in delegates {
                        delegate.arSessionDidUpdatePosition?(position)
                        delegate.arSessionDidUpdateTransform?(transform)
                    }
                }
                try? await Task.sleep(for: .seconds(0.1))
            }
        }
    }

    // MARK: - Transform Access

    /// Get the current device transform. Returns nil if tracking is not running.
    public func getTransform() -> simd_float4x4? {
        guard isTracking,
              worldTracking.state == .running,
              let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }

        return deviceAnchor.originFromAnchorTransform
    }

    /// Query device anchor at a specific timestamp.
    /// - Parameter timestamp: The timestamp to query the device anchor at
    /// - Returns: The device transform at the specified time, or nil if unavailable
    public func queryDeviceTransform(atTimestamp timestamp: TimeInterval) -> simd_float4x4? {
        guard isTracking,
              worldTracking.state == .running,
              let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: timestamp) else {
            return nil
        }

        return deviceAnchor.originFromAnchorTransform
    }

    /// Get the position from the current device transform.
    public func getPosition() -> [Double]? {
        guard let transform = getTransform() else {
            return nil
        }
        return transform.position.toDouble()
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
