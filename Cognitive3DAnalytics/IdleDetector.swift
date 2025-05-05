//
//  IdleDetector.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import simd

public extension Notification.Name {
    static let idleStateChanged = Notification.Name("cognitive3d.idleStateChanged")
}


/// The `IdleDetector` class when active will monitor if the user has not interacted with the application for time threshold. If the threshold is passed, the current analytics sessions is ended.
///  See the  ``Config`` class and the properties `shouldEndSessionOnIdle`, `idleThreshold`.
@Observable public class IdleDetector: ARSessionDelegate {
    // MARK: - Properties
    private let logger = CognitiveLog(category: "IdleDetector")
    private var lastPosition: [Double]?
    private var lastRotation: simd_quatf?
    private var lastActivityTime: TimeInterval

    private let positionThreshold: Double
    private let rotationThreshold: Double // in radians
    private let idleThreshold: TimeInterval

    public private(set) var isIdle: Bool = false {
    didSet {
        if isIdle != oldValue {
            NotificationCenter.default.post(
                name: .idleStateChanged,
                object: self,
                userInfo: ["isIdle": isIdle]
            )
        }
    }
}

    // MARK: - Initialization
    public init(
        positionThreshold: Double = 0.01, // 1cm movement threshold
        rotationThreshold: Double = 0.017, // ~1 degree rotation threshold
        idleThreshold: TimeInterval = 60.0 // 60 seconds of no movement
    ) {
        self.positionThreshold = positionThreshold
        self.rotationThreshold = rotationThreshold
        self.idleThreshold = idleThreshold
        self.lastActivityTime = Date().timeIntervalSince1970

        // Register for AR session updates
        ARSessionManager.shared.addDelegate(self)
    }

    deinit {
        ARSessionManager.shared.removeDelegate(self)
    }

    // MARK: - ARSessionDelegate Methods
    public func arSessionDidUpdatePosition(_ position: [Double]) {
        checkForMovement(position: position)
    }

    public func arSessionDidUpdateTransform(_ transform: simd_float4x4) {
        let rotation = simd_quaternion(transform.rotationMatrix)
        checkForRotation(rotation: rotation)
    }

    // MARK: - Movement Detection
    private func checkForMovement(position: [Double]) {
        guard let lastPosition = lastPosition else {
            self.lastPosition = position
            return
        }

        // Calculate distance moved
        let distance = sqrt(
            pow(position[0] - lastPosition[0], 2) +
            pow(position[1] - lastPosition[1], 2) +
            pow(position[2] - lastPosition[2], 2)
        )

        if distance > positionThreshold {
            updateActivity()
        }

        self.lastPosition = position
        checkIdleState()
    }

    private func checkForRotation(rotation: simd_quatf) {
        guard let lastRotation = lastRotation else {
            self.lastRotation = rotation
            return
        }

        // Calculate angle between quaternions
        let dot = abs(
            rotation.vector.x * lastRotation.vector.x +
            rotation.vector.y * lastRotation.vector.y +
            rotation.vector.z * lastRotation.vector.z +
            rotation.real * lastRotation.real
        )

        let angle = Double(2 * acos(min(1, dot)))

        if angle > rotationThreshold {
            updateActivity()
        }

        self.lastRotation = rotation
        checkIdleState()
    }

    // MARK: - Idle State Management
    private func updateActivity() {
        lastActivityTime = Date().timeIntervalSince1970
        if isIdle {
            isIdle = false
            logger.info("User activity detected - no longer idle")
        }
    }

    private func checkIdleState() {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastActivity = currentTime - lastActivityTime

        let shouldBeIdle = timeSinceLastActivity >= idleThreshold
        if shouldBeIdle != isIdle {
            isIdle = shouldBeIdle
            if isIdle {
                logger.info("User has been idle for \(String(format: "%.1f", timeSinceLastActivity)) seconds")
            }
        }
    }

    // MARK: - Public Methods
    public func getTimeSinceLastActivity() -> TimeInterval {
        return Date().timeIntervalSince1970 - lastActivityTime
    }

    public func resetIdleTimer() {
        updateActivity()
    }
}
