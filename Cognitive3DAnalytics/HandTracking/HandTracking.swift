//
//  HandTracking.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//
//
// This static class works to record hand tracking data.
// A special type of dynamic object is created; a "controller" is created for each hand.
//
// Note: hand tracking is not enabled by default in visionOS.
// The use of hand tracking needs to be authorized by the application user.
//

import ARKit
import Combine
import Foundation
import RealityKit
import SwiftUI

/// Protocol for receiving hand tracking data updates
public protocol HandTrackingDelegate: AnyObject {
    /// Called when hand transform data is updated
    /// - Parameters:
    ///   - handData: The processed hand tracking data
    func handTrackingDidUpdate(_ handData: HandTrackingData)
}

/// Data structure containing processed hand tracking information
public struct HandTrackingData {
    /// Unique identifier for the hand (matches dynamic object ID used by C3D backend)
    public let handId: String

    /// Hand laterality - determines if this is the left or right hand
    public let chirality: HandAnchor.Chirality

    /// Raw wrist transform in world coordinate space, combining hand anchor position with wrist joint offset
    public let worldTransform: simd_float4x4

    /// Transform with rotation adjustments applied for proper hand mesh visualization and orientation
    // Note: the  displaying of hand meshes is only being done in development using a delegate
    // class.
    public let visualTransform: simd_float4x4

    /// Current tracking state - true when hand is visible to HMD cameras and actively tracked
    public let isTracked: Bool

    /// Unix timestamp (seconds since epoch) when this hand data was captured
    public let timestamp: TimeInterval

    /// Flag indicating if the tracking state has changed since the last update (edge detection)
    public let hasStateChanged: Bool

    public init(
        handId: String,
        chirality: HandAnchor.Chirality,
        worldTransform: simd_float4x4,
        visualTransform: simd_float4x4,
        isTracked: Bool,
        timestamp: TimeInterval,
        hasStateChanged: Bool = false
    ) {
        self.handId = handId
        self.chirality = chirality
        self.worldTransform = worldTransform
        self.visualTransform = visualTransform
        self.isTracked = isTracked
        self.timestamp = timestamp
        self.hasStateChanged = hasStateChanged
    }
}

/// Hand tracking state tracker for detecting state changes
private struct HandTrackingState {
    var isTracked: Bool

    init(isTracked: Bool = false) {
        self.isTracked = isTracked
    }
}

/// Hand tracking class, this class works with dynamic objects to record the hand anchors to send to the C3D SDK back end.
/// A dynamic object records are peridoically created using a dynamic object system.
public class HandTracking: NSObject {

    // Hand tracking requires working with an AR session and a hand tracking provider.
    /// For dealing with AR session authorization
    static var arSession = ARKitSession()

    /// Hand tracker provider in visionOS
    static let handTracking = HandTrackingProvider()

    // The dynamic identifiers correspond to the identifiers used by the C3D back end.
    // When dynamic objects are being created and uploaded to the back end, these identifiers also
    // need to be included in that workflow.

    /// Dynamic object ID for the left hand
    public static var leftHandId = "HAND-LEFT-0001"

    /// Dynamic object ID for the right hand
    public static var rightHandId = "HAND-RIGHT-0002"

    /// Debug setting to use a mesh instead of registering a hand object for the dynamic object.
    /// The mesh needs to have been uploaded when configuring a  project that has integrated the C3D SDK.
    private static var useMesh = false

    private static var dynamicManager: DynamicDataManager?

    private static var core: Cognitive3DAnalyticsCore?

    static var handLeftFilename: String = "handLeft"
    static var handRightFilename: String = "handRight"

    // MARK: - State Tracking
    /// Track the previous state of each hand for edge detection
    private static var leftHandState = HandTrackingState()
    private static var rightHandState = HandTrackingState()

    // MARK: - Hand Components

    private static var leftHandComponent: HandComponent = {
        return HandComponent(
            dynamicId: leftHandId,
            name: "leftHand",
            /// Note: the mesh name corresponds to the mesh name being used in the scene viewer in the back end.
            mesh: "leftHand"
        )
    }()

    private static var rightHandComponent: HandComponent = {
        return HandComponent(
            dynamicId: rightHandId,
            name: "rightHand",
            /// Note: the mesh name corresponds to the mesh name being used in the scene viewer in the back end.
            mesh: "rightHand"
        )
    }()

    // MARK: - Delegate
    /// The delegate is optionally being used to provide visual debugging with the wrist anchors by rendering hand meshes in an application.
    public static weak var delegate: HandTrackingDelegate?

    // MARK: - Setup
    public static func setup(core: Cognitive3DAnalyticsCore) {
        self.core = core
        dynamicManager = core.dynamicDataManager
        HandComponent.registerComponent()

        // Initialize hand states
        leftHandState = HandTrackingState()
        rightHandState = HandTrackingState()
    }

    /// Configure hand tracking with a root entity (similar to configureDynamicObjects pattern)
    /// This should be called from your ImmersiveView after the scene is loaded
    /// - Parameter rootEntity: The root entity to attach hand visualizations to
    public static func configure() {
        registerHandObjects()
        core?.setSessionProperty(key: "c3d.handtracking.configured", value: true)
        core?.logger?.info("Hand tracking configured")
    }

    /// Register hand objects with the dynamic data manager
    private static func registerHandObjects() {
        guard let dynamicManager = dynamicManager else { return }

        Task {
            if useMesh {
                // Register as dynamic objects with meshes
                await dynamicManager.registerDynamicObject(
                    id: leftHandId,
                    name: "leftHand",
                    mesh: "leftHand"
                )

                await dynamicManager.registerDynamicObject(
                    id: rightHandId,
                    name: "rightHand",
                    mesh: "rightHand"
                )
            } else {
                // Register as hand objects (preferred method)
                await dynamicManager.registerHand(
                    id: leftHandId,
                    isRightHand: false
                )

                await dynamicManager.registerHand(
                    id: rightHandId,
                    isRightHand: true
                )
            }
        }
    }

    // MARK: - Update Rate Logic
    /// Determines if a hand should be updated based on its individual updateRate, gaze sync setting, or properties
    private static func shouldUpdateHand(_ component: HandComponent, currentTime: TimeInterval, hasProperties: Bool)
        -> Bool
    {
        // Always update if we have properties (like enabled state changes)
        if hasProperties {
            return true
        }

        // For gaze-synced hands, limit to 30 FPS instead of every frame
        if component.syncWithGaze {
            // Simple modulo-based rate limiting for gaze sync
            let frameNumber = Int(currentTime * 30)  // 30 FPS
            return frameNumber % 1 == 0  // Update every frame at 30 FPS
        }

        // For regular hands, use simple time-based check
        let updateInterval = TimeInterval(component.updateRate)
        let frameNumber = Int(currentTime / updateInterval)
        let lastFrameNumber = Int((currentTime - 0.016) / updateInterval)  // Assume ~60 FPS

        // Update if we've crossed into a new update interval
        return frameNumber != lastFrameNumber
    }

    // MARK: - Hand Tracking Session
    /// Check and request authorization before starting hand tracking
    private static func handTrackingIsAuthorized(session: ARKitSession) async -> Bool {
        let results = await session.requestAuthorization(for: HandTrackingProvider.requiredAuthorizations)
        return results.allSatisfy { $0.value == .allowed }
    }

    /// Start hand tracking; the method will check that hand tracking is authorized by the user before starting hand tracking.
    @MainActor
    public static func runSession() async {
        let session = ARKitSession()
        let handTracking = HandTrackingProvider()

        // Check that hand tracking has been authorized by the user
        if await handTrackingIsAuthorized(session: session) {
            await startHandTrackingSession(session: session, handTracking: handTracking)
        } else {
            core?.logger?.warning("Hand tracking authorization denied")
            core?.setSessionProperty(key: "c3d.app.handtracking.declined", value: true)
        }

        // Process hand tracking updates
        await processHandTrackingUpdates(handTracking: handTracking)
    }

    private static func startHandTrackingSession(session: ARKitSession, handTracking: HandTrackingProvider) async {
        do {
            // Start hand tracking
            try await session.run([handTracking])
            core?.logger?.info("Hand tracking started")
            core?.setSessionProperty(key: "c3d.app.handtracking.enabled", value: true)
        } catch let error as ARKitSession.Error {
            core?.logger?.error(
                "The app has encountered an error while running providers: \(error.localizedDescription)"
            )
            core?.setSessionProperty(key: "c3d.app.handtracking.error", value: true)
        } catch {
            core?.logger?.error("The app has encountered an unexpected error: \(error.localizedDescription)")
            core?.setSessionProperty(key: "c3d.app.handtracking.error", value: true)
        }
    }

    private static func processHandTrackingUpdates(handTracking: HandTrackingProvider) async {
        for await anchorUpdate in handTracking.anchorUpdates {
            let handAnchor = anchorUpdate.anchor
            let timestamp = Date().timeIntervalSince1970

            // Always detect state changes, regardless of joint availability
            let hasStateChanged = detectStateChange(
                for: handAnchor.chirality,
                currentlyTracked: handAnchor.isTracked
            )

            // Handle untracked hands
            if !handAnchor.isTracked {
                if hasStateChanged {
                    await recordUntrackedHandState(handAnchor: handAnchor, timestamp: timestamp)
                }
                continue
            }

            // Only process position updates if tracked and joints available
            guard let wristJoint = handAnchor.handSkeleton?.joint(.wrist),
                wristJoint.isTracked
            else { continue }

            await processHandUpdate(handAnchor: handAnchor, wristJoint: wristJoint, hasStateChanged: hasStateChanged)
        }
    }

    private static func processHandUpdate(handAnchor: HandAnchor, wristJoint: HandSkeleton.Joint, hasStateChanged: Bool)
        async
    {
        let timestamp = Date().timeIntervalSince1970
        let handId = handAnchor.chirality == .left ? leftHandId : rightHandId

        // Get the base wrist transform in world space
        // This combines the hand anchor's position with the wrist joint's local position
        let wristTransform = handAnchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform

        // Create visual transform with rotation adjustments for proper mesh display
        let visualTransform = applyHandMeshRotations(
            transform: wristTransform,
            chirality: handAnchor.chirality
        )

        // Create hand tracking data with state change information
        let handData = HandTrackingData(
            handId: handId,
            chirality: handAnchor.chirality,
            worldTransform: wristTransform,
            visualTransform: visualTransform,
            isTracked: handAnchor.isTracked,
            timestamp: timestamp,
            hasStateChanged: hasStateChanged
        )

        // Notify delegate of the update
        delegate?.handTrackingDidUpdate(handData)

        // Record the hand data for analytics
        await recordHandData(handData: handData)
    }

    private static func recordUntrackedHandState(handAnchor: HandAnchor, timestamp: TimeInterval) async {
        let handId = handAnchor.chirality == .left ? leftHandId : rightHandId

        let handData = HandTrackingData(
            handId: handId,
            chirality: handAnchor.chirality,
            worldTransform: simd_float4x4(1),
            visualTransform: simd_float4x4(1),
            isTracked: false,
            timestamp: timestamp,
            hasStateChanged: true
        )
        await recordHandData(handData: handData)
    }

    // MARK: - State Change Detection
    /// Detect if the hand tracking state has changed and update internal state
    private static func detectStateChange(
        for chirality: HandAnchor.Chirality,
        currentlyTracked: Bool
    ) -> Bool {
        if chirality == .left {
            let hasStateChanged = leftHandState.isTracked != currentlyTracked

            leftHandState.isTracked = currentlyTracked
            return hasStateChanged
        } else {
            let hasStateChanged = rightHandState.isTracked != currentlyTracked

            rightHandState.isTracked = currentlyTracked
            return hasStateChanged
        }
    }

    // MARK: - Hand Data Processing
    /// Process hand tracking updates and notify delegate
    private static func processHandUpdate(handAnchor: HandAnchor, wristJoint: HandSkeleton.Joint) async {
        let timestamp = Date().timeIntervalSince1970

        // Always detect state change first
        let hasStateChanged = detectStateChange(for: handAnchor.chirality, currentlyTracked: handAnchor.isTracked)

        let handId = handAnchor.chirality == .left ? leftHandId : rightHandId

        // Always record data - whether tracked or not
        if handAnchor.isTracked && wristJoint.isTracked {
            // Process normal hand data with position
            // Get the base wrist transform in world space
            // This combines the hand anchor's position with the wrist joint's local position
            let wristTransform = handAnchor.originFromAnchorTransform * wristJoint.anchorFromJointTransform

            // Create visual transform with rotation adjustments for proper mesh display
            let visualTransform = applyHandMeshRotations(
                transform: wristTransform,
                chirality: handAnchor.chirality
            )

            // Create hand tracking data with state change information
            let handData = HandTrackingData(
                handId: handId,
                chirality: handAnchor.chirality,
                worldTransform: wristTransform,
                visualTransform: visualTransform,
                isTracked: handAnchor.isTracked,
                timestamp: timestamp,
                hasStateChanged: hasStateChanged
            )

            // Notify delegate of the update
            delegate?.handTrackingDidUpdate(handData)

            // Record the hand data for analytics
            await recordHandData(handData: handData)
        } else if hasStateChanged {
            // Just record the state change without position data
            let handData = HandTrackingData(
                handId: handId,
                chirality: handAnchor.chirality,
                worldTransform: simd_float4x4(1),  // identity matrix
                visualTransform: simd_float4x4(1),  // identity matrix
                isTracked: false,
                timestamp: timestamp,
                hasStateChanged: true
            )

            await recordHandData(handData: handData)
        }
    }

    /// Apply rotation adjustments to hand transforms for proper mesh orientation
    /// - Parameters:
    ///   - transform: The base wrist transform
    ///   - chirality: Whether this is a left or right hand
    /// - Returns: Transform with rotation adjustments applied
    private static func applyHandMeshRotations(
        transform: simd_float4x4,
        chirality: HandAnchor.Chirality
    ) -> simd_float4x4 {
        var adjustedTransform = transform

        if chirality == .left {
            // Left hand rotation adjustments:
            // 1. Rotate -90° around X-axis to orient the mesh properly
            // 2. Rotate 90° around Y-axis to align with hand direction
            let xRotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            let yRotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            let combinedRotation = xRotation * yRotation
            adjustedTransform = adjustedTransform * simd_float4x4(combinedRotation)
        } else {
            // Right hand rotation adjustments:
            // 1. Rotate 90° around X-axis to orient the mesh properly
            // 2. Rotate -90° around Z-axis to align with hand direction
            let xRotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            let zRotation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
            let combinedRotation = zRotation * xRotation
            adjustedTransform = adjustedTransform * simd_float4x4(combinedRotation)
        }

        return adjustedTransform
    }

    /// Record hand data to the analytics system with conditional properties
    /// Now includes update rate timing control to match DynamicObjectSystem behavior
    private static func recordHandData(handData: HandTrackingData) async {
        let component = handData.chirality == .left ? leftHandComponent : rightHandComponent
        let hasProperties = handData.hasStateChanged

        // Check if we should update based on updateRate timing and component settings
        if !shouldUpdateHand(component, currentTime: handData.timestamp, hasProperties: hasProperties) {
            return  // Skip this update due to rate limiting
        }

        // Extract position from the world transform matrix using framework extension
        let position = handData.worldTransform.position

        // Get base rotation from world transform (actual hand orientation)
        let baseRotation = simd_quatf(handData.worldTransform.rotationMatrix)

        // Apply corrections based on hand chirality
        let rotation: simd_quatf
        if handData.chirality == .right {
            let yRotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            let zRotation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            rotation = baseRotation * yRotation * zRotation
        } else {
            let yRotation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            let zRotation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            let flipRotation = simd_quatf(angle: .pi, axis: [1, 0, 0])
            rotation = baseRotation * yRotation * zRotation * flipRotation
        }

        let scale = SIMD3<Float>(1.0, 1.0, 1.0)

        // Only include enabled property when state has changed
        let properties: [[String: AnyCodable]]? =
            handData.hasStateChanged ? [["enabled": AnyCodable(handData.isTracked)]] : nil

        if properties != nil {
            core?.logger?.verbose(
                "\(handData.chirality == .right ? "Right" : "Left") hand tracking \(handData.isTracked)"
            )
        }

        // Record the data with the dynamic manager using component-specific thresholds
        await dynamicManager?.recordDynamicObject(
            id: component.dynamicId,
            position: position,
            rotation: rotation,
            scale: scale,
            positionThreshold: component.positionThreshold,
            rotationThreshold: component.rotationThreshold,
            scaleThreshold: component.scaleThreshold,
            updateRate: component.updateRate,
            properties: properties
        )
    }

    // MARK: - Session Events
    public func sessionDidStart(sessionId: String) {
        // Reset hand states when session starts
        Self.leftHandState = HandTrackingState()
        Self.rightHandState = HandTrackingState()
    }

    public func sessionDidEnd(sessionId: String, sessionState: SessionState) {
        // Handle session end cleanup if needed
    }

    // MARK: - Public API for Hand Component Access
    /// Get the hand component for a specific chirality
    public static func getHandComponent(for chirality: HandAnchor.Chirality) -> HandComponent {
        return chirality == .left ? leftHandComponent : rightHandComponent
    }

    /// Update hand component configuration
    /// Note: Changes to updateRate will affect future timing decisions
    public static func updateHandComponent(
        for chirality: HandAnchor.Chirality,
        updateRate: Float? = nil,
        positionThreshold: Float? = nil,
        rotationThreshold: Float? = nil,
        scaleThreshold: Float? = nil
    ) {
        if chirality == .left {
            if let updateRate = updateRate { leftHandComponent.updateRate = updateRate }
            if let positionThreshold = positionThreshold { leftHandComponent.positionThreshold = positionThreshold }
            if let rotationThreshold = rotationThreshold { leftHandComponent.rotationThreshold = rotationThreshold }
            if let scaleThreshold = scaleThreshold { leftHandComponent.scaleThreshold = scaleThreshold }
        } else {
            if let updateRate = updateRate { rightHandComponent.updateRate = updateRate }
            if let positionThreshold = positionThreshold { rightHandComponent.positionThreshold = positionThreshold }
            if let rotationThreshold = rotationThreshold { rightHandComponent.rotationThreshold = rotationThreshold }
            if let scaleThreshold = scaleThreshold { rightHandComponent.scaleThreshold = scaleThreshold }
        }
    }

    // MARK: - Debug/Testing API
    /// Get current tracking state for a hand (useful for debugging)
    public static func getCurrentTrackingState(for chirality: HandAnchor.Chirality) -> Bool {
        return chirality == .left ? leftHandState.isTracked : rightHandState.isTracked
    }
}
