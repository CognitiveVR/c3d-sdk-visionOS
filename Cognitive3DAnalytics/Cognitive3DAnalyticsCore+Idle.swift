//
//  Cognitive3DAnalyticsCore_Idle.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2025-02-20.
//

import Foundation


// MARK: - Idle Detection
extension Cognitive3DAnalyticsCore {
    internal func setupIdleDetection(
        positionThreshold: Double = 0.01,
        rotationThreshold: Double = 0.017,
        idleThreshold: TimeInterval = 5.0
    ) {
        // Create the idle detector
        idleDetector = IdleDetector(
            positionThreshold: positionThreshold,
            rotationThreshold: rotationThreshold,
            idleThreshold: idleThreshold
        )

        // Setup notification observation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIdleStateChange(_:)),
            name: .idleStateChanged,
            object: idleDetector
        )
    }

    internal func cleanupIdleDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: .idleStateChanged,
            object: idleDetector
        )
        idleDetector = nil
    }

    @objc private func handleIdleStateChange(_ notification: Notification) {
        guard let isIdle = notification.userInfo?["isIdle"] as? Bool else { return }

        Task {
            // Record the idle state change as a custom event
            let eventName = isIdle ? "c3d.userIdleStart" : "c3d.userIdleEnd"

            // Get idle duration before any potential cleanup
            let idleDuration = idleDetector?.getTimeSinceLastActivity() ?? 0

            let properties: [String: Any] = [
                "idleDuration": idleDuration
            ]

            // Get current position if available
            let position = coordSystem.convertPosition(getCurrentHMDPosition())

            recordCustomEvent(
                name: eventName,
                position: position,
                properties: properties,
                immediate: true
            )

            logger?.info("\(isIdle ? "User became idle" : "User activity resumed") - Duration: \(String(format: "%.1f", idleDuration))s")

            if config?.shouldEndSessionOnIdle == true && isIdle {
                // Use the already captured idle duration
                let sessionId = getSessionId()

                if await endSession() {
                    sessionDelegate?.sessionDidEnd(sessionId: sessionId, sessionState: .endedIdle(timeInterval: idleDuration))
                    logger?.info("Session ended due to idle timeout after \(String(format: "%.1f", idleDuration))s")
                }
            }
        }
    }
    
    // MARK: - Public Interface

    /// Get the current idle state of the user
    public var isUserIdle: Bool {
        return idleDetector?.isIdle ?? false
    }

    /// Get the time since last user activity in seconds
    public var timeSinceLastActivity: TimeInterval {
        return idleDetector?.getTimeSinceLastActivity() ?? 0
    }

    /// Reset the idle timer manually
    public func resetIdleTimer() {
        idleDetector?.resetIdleTimer()
    }
}
