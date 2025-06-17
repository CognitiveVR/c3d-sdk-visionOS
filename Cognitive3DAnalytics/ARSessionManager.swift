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

/// Use the AR Session manager to get the transform for the world anchor for the HMD.
public class ARSessionManager {
    // MARK: - Properties
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private let logger = CognitiveLog()
    private var isTracking = false
    private var delegates: [ARSessionDelegate] = []
    
    // MARK: - Singleton
    public static let shared = ARSessionManager()

    public var isTrackingActive: Bool {
        return isTracking
    }

    private init() {}
    
    // MARK: - Delegate Management
    public func addDelegate(_ delegate: ARSessionDelegate) {
        delegates.append(delegate)
    }
    
    public func removeDelegate(_ delegate: ARSessionDelegate) {
        delegates.removeAll { $0 === delegate }
    }
    
    // MARK: - Session Management
    public func startTracking() async {
        guard !isTracking else {
            logger.warning("ARSessionManager: Tracking already active")
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
                if let transform = getCurrentTransform() {
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
    private func getCurrentTransform() -> simd_float4x4? {
        guard isTracking,
              worldTracking.state == .running,
              let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }

        // Return the transform for the HMD device.
        return deviceAnchor.originFromAnchorTransform
    }

    /// Get the position from the current device transform.
    public func getPosition() -> [Double]? {
        guard let transform = getCurrentTransform() else {
            return nil
        }
        return transform.position.toDouble()
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }
}
