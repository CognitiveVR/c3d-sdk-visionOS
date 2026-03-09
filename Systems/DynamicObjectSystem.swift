//
//  DynamicObjectSystem.swift
//  Cognitive3D SDK Example
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//
//
// OVERVIEW:
// This system tracks dynamic objects in a RealityKit scene and sends their transform data
// to the Cognitive3D analytics backend. It respects per-object update rates and handles
// object lifecycle (enabled/disabled states).
//
// CONCURRENCY DESIGN:
// Uses the Actor Model pattern for thread-safe timing management:
// - TimingInfoManager actor isolates the timing array from concurrent access
// - All timing operations are serialized through async actor calls
// - Eliminates race conditions that could cause index-out-of-bounds crashes
// - Integrates with Swift's async/await concurrency system
//
// UPDATE FLOW:
// 1. System.update() called by RealityKit (potentially from multiple threads)
// 2. processEntities() iterates through all entities with DynamicComponent
// 3. For each entity:
//    - Check if enabled/disabled state changed
//    - Consult TimingInfoManager actor to see if enough time has passed for update
//    - If update needed, send transform data to Cognitive3D analytics
//
// TIMING CONTROL:
// - Each dynamic object has its own updateRate (from DynamicComponent)
// - Objects with syncWithGaze=true use the gaze records update rate.
// - TimingInfoManager tracks per-object timing to avoid unnecessary processing
// - First update for each object always sends enabled:true property
//
// THREAD SAFETY:
// - All entity property access wrapped in MainActor.run blocks
// - Timing state managed exclusively by TimingInfoManager actor
// - Session state changes handled through async Task blocks
// - No direct shared mutable state outside of actor boundaries
//
// LIFECYCLE:
// - Subscribes to Cognitive3D session events (start/end)
// - Clears timing data when sessions end to prevent memory leaks
// - Handles entity removal from scene by cleaning up timing state

import Cognitive3DAnalytics
import Combine
import Foundation
import RealityKit
// If you are using a USD scene created with Reality Composer Pro, you want to include this import.
// If you are creating entities in code, you can omit this import.
import RealityKitContent

/// Timing information for individual dynamic objects to respect their update rates
private struct EntityTimingInfo {
    let entityId: String
    var lastUpdate: Double
    var nextUpdate: Double
    var isGazeSynced: Bool

    init(entityId: String, updateRate: Double, currentTime: Double, isGazeSynced: Bool = false) {
        self.entityId = entityId
        self.lastUpdate = currentTime
        self.nextUpdate = currentTime + updateRate
        self.isGazeSynced = isGazeSynced
    }

    mutating func scheduleNextUpdate(updateRate: Double, currentTime: Double) {
        self.lastUpdate = currentTime
        self.nextUpdate = currentTime + updateRate
    }

    func shouldUpdate(currentTime: Double) -> Bool {
        return currentTime >= nextUpdate
    }
}

/// Actor to manage timing info with Swift concurrency
private actor TimingInfoManager {
    private var entityTimingInfos: [EntityTimingInfo] = []

    func checkUpdateTiming(entityId: String, updateRate: Double, currentTime: Double, isGazeSynced: Bool) -> (shouldUpdate: Bool, isFirstUpdate: Bool) {
        // Find existing timing info for this entity
        if let index = entityTimingInfos.firstIndex(where: { $0.entityId == entityId }) {
            var timingInfo = entityTimingInfos[index]

            // Update gaze sync status if changed
            timingInfo.isGazeSynced = isGazeSynced

            if timingInfo.shouldUpdate(currentTime: currentTime) {
                timingInfo.scheduleNextUpdate(updateRate: updateRate, currentTime: currentTime)
                entityTimingInfos[index] = timingInfo
                return (shouldUpdate: true, isFirstUpdate: false)
            } else {
                // Update the timing info even if not updating (for gaze sync status)
                entityTimingInfos[index] = timingInfo
                return (shouldUpdate: false, isFirstUpdate: false)
            }
        } else {
            // First time seeing this entity - create new timing info and allow update
            let newTimingInfo = EntityTimingInfo(
                entityId: entityId,
                updateRate: updateRate,
                currentTime: currentTime,
                isGazeSynced: isGazeSynced
            )
            entityTimingInfos.append(newTimingInfo)
            return (shouldUpdate: true, isFirstUpdate: true)
        }
    }

    func removeEntity(entityId: String) {
        entityTimingInfos.removeAll { $0.entityId == entityId }
    }

    func removeAllEntities() {
        entityTimingInfos.removeAll()
    }
}

/// This class works with the Dynamic object manager in the C3D SDK to record dynamic object data for the active analytics session.
public final class DynamicObjectSystem: System, @unchecked Sendable {
    // Query to find all entities with DynamicComponent
    private static let query = EntityQuery(where: .has(DynamicComponent.self))

    // Track which objects have sent their initial enabled property (mirrors Unity's hasEnabled)
    private var hasEnabledStates: [String: Bool] = [:]

    // Track last known enabled state for each object
    private var lastEnabledStates: [String: Bool] = [:]

    // Use actor for thread-safe timing management
    private let timingManager = TimingInfoManager()

    // Accumulated time tracker for delta-time based timing
    private var currentTime: Double = 0.0
    private var lastProcessTime: Double = 0.0
    private var minimumProcessInterval: Double {
        guard let config = Cognitive3DAnalyticsCore.shared.config else {
            return 1.0 / 30.0
        }

        // Runtime lookup keeps this file source-compatible with older Config definitions.
        if
            let configuredInterval = Mirror(reflecting: config).children.first(where: { $0.label == "dynamicObjectProcessInterval" })?.value as? Double,
            configuredInterval > 0
        {
            return configuredInterval
        }
        return 1.0 / 30.0
    }

    private var isProcessing = false
    private let stateQueue = DispatchQueue(label: "com.cognitive3d.dynamicobjectsystem.state")

    // The dynamic object manager in the C3D SDK.
    private var dynamicManager: DynamicDataManager?

    private var isSessionEnding: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var isDebugVerbose = false

    // Required initializer for RealityKit System
    public required init(scene: Scene) {
        guard let manager = Cognitive3DAnalyticsCore.shared.dynamicDataManager else {
            // No dynamic manager available - system will be inactive
            return
        }

        self.dynamicManager = manager

        // Subscribe to session events
        Cognitive3DAnalyticsCore.shared.sessionEventPublisher
            .sink { [weak self] event in
                Task { [weak self] in
                    switch event {
                    case .ended:
                        self?.isSessionEnding = true
                        await self?.timingManager.removeAllEntities()
                        self?.stateQueue.async {
                            self?.currentTime = 0.0
                            self?.lastProcessTime = 0.0
                            self?.isProcessing = false
                        }
                    case .started:
                        self?.isSessionEnding = false
                        self?.stateQueue.async {
                            self?.currentTime = 0.0
                            self?.lastProcessTime = 0.0
                            self?.isProcessing = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // Using a system, record the transforms of dynamic objects. The data gets posted to the C3D servers.
    public func update(context: SceneUpdateContext) {
        let frameTime: Double? = stateQueue.sync {
            // Accumulate time using deltaTime from SceneUpdateContext
            currentTime += context.deltaTime

            guard currentTime - lastProcessTime >= minimumProcessInterval else {
                return nil
            }

            guard !isProcessing else {
                return nil
            }

            lastProcessTime = currentTime
            isProcessing = true
            return currentTime
        }

        guard let frameTime else {
            return
        }

        let entities = Array(context.entities(matching: Self.query, updatingSystemWhen: .rendering))

        Task { [weak self] in
            guard let self else { return }
            defer {
                self.stateQueue.async {
                    self.isProcessing = false
                }
            }
            await processEntities(entities: entities, frameTime: frameTime)
        }
    }

    /// Get the position, scale & rotation for a entity to create a dynamic record to eventually post the C3D back end.
    /// And also handle if the enabled state for a dynamic object has changed.
    /// Respects per-object updateRate timing to avoid unnecessary processing.
    private func processEntities(entities: [Entity], frameTime: Double) async {
        guard !isSessionEnding else { return }

        for entity in entities {
            // Capture component and entity state in one MainActor hop.
            guard let entityState = await captureEntityState(entity) else {
                continue
            }
            let dynamicComponent = entityState.dynamicComponent

            // Capture current entity state
            let isParentNil = entityState.isParentNil
            let isEntityActive = entityState.isEntityActive
            let isEnabled = !isParentNil && isEntityActive
            let id = dynamicComponent.dynamicId

            // Handle based on enabled state
            if !isEnabled {
                await handleDisabledEntity(entity, dynamicComponent: dynamicComponent, id: id, isParentNil: isParentNil)
                continue
            }

            // Check if this entity should be updated based on its individual updateRate
            // or if it's synced with gaze tracking
            // IMPORTANT: Always allow first update to ensure enabled:true is sent
            let (shouldUpdate, isFirstUpdate) = await shouldUpdateEntityNow(dynamicComponent, currentTime: frameTime)
            let needsEnabledProperty = await MainActor.run {
                !(hasEnabledStates[id] ?? false)
            }

            // Always update if this is the first time we're seeing this entity OR
            // if we need to send the enabled property OR if timing says we should update
            if !shouldUpdate && !isFirstUpdate && !needsEnabledProperty {
                continue
            }

            await handleEnabledEntity(entity, dynamicComponent: dynamicComponent)
        }
    }

    /// Determines if an entity should be updated based on its individual updateRate or gaze sync setting
    private func shouldUpdateEntityNow(_ component: DynamicComponent, currentTime: Double) async -> (shouldUpdate: Bool, isFirstUpdate: Bool) {
        let entityId = component.dynamicId

        if component.syncWithGaze {
            return await shouldUpdateGazeSyncedEntity(entityId: entityId, currentTime: currentTime)
        } else {
            return await shouldUpdateRegularEntity(
                entityId: entityId,
                updateRate: component.updateRate,
                currentTime: currentTime
            )
        }
    }

    /// Handle gaze-synced entity timing with appropriate update rate
    private func shouldUpdateGazeSyncedEntity(entityId: String, currentTime: Double) async -> (shouldUpdate: Bool, isFirstUpdate: Bool) {
        let gazeUpdateRate = 1.0 / 30.0  // 30 FPS for gaze sync
        return await timingManager.checkUpdateTiming(
            entityId: entityId,
            updateRate: gazeUpdateRate,
            currentTime: currentTime,
            isGazeSynced: true
        )
    }

    /// Handle regular entity timing based on component updateRate
    private func shouldUpdateRegularEntity(entityId: String, updateRate: Float, currentTime: Double) async -> (shouldUpdate: Bool, isFirstUpdate: Bool) {
        return await timingManager.checkUpdateTiming(
            entityId: entityId,
            updateRate: Double(updateRate),
            currentTime: currentTime,
            isGazeSynced: false
        )
    }

    /// Handle entity that is currently disabled
    private func handleDisabledEntity(_ entity: Entity, dynamicComponent: DynamicComponent, id: String, isParentNil: Bool) async {
        let entityExists = !isParentNil

        if entityExists {
            // Entity is disabled but still in scene - just send enabled:false
            let properties: [[String: AnyCodable]]? = [["enabled": AnyCodable(false)]]
            await updateEntityTransform(entity, dynamicComponent: dynamicComponent, properties: properties)
        } else {
            // Entity is actually removed from scene
            await dynamicManager?.removeDynamicObject(id: id)
            await timingManager.removeEntity(entityId: id)
        }

        // Update state tracking
        await MainActor.run {
            lastEnabledStates[id] = entityExists
        }
    }

    /// Handle entity that is currently enabled
    @discardableResult
    private func handleEnabledEntity(_ entity: Entity, dynamicComponent: DynamicComponent) async -> Bool {
        let id = dynamicComponent.dynamicId

        // Determine if we need to send enabled:true (only on first enable, matching Unity's !hasEnabled check)
        let shouldSendEnabledProperty = await MainActor.run {
            // Always update our enabled state tracking
            lastEnabledStates[id] = true

            // Check if this is the first time we're sending enabled:true for this object
            // This mirrors Unity's !ActiveDynamicObjectsArray[i].hasEnabled check
            let hasAlreadySentEnabled = hasEnabledStates[id] ?? false
            if !hasAlreadySentEnabled {
                // Mark that we've now sent enabled:true for this object
                hasEnabledStates[id] = true
                return true
            }
            return false
        }

        // Create properties: only include enabled:true if this is the first time
        // This exactly matches Unity's behavior
        let properties: [[String: AnyCodable]]? = shouldSendEnabledProperty ? [["enabled": AnyCodable(true)]] : nil

        if isDebugVerbose && shouldSendEnabledProperty {
            print("DynamicObjectSystem: Sending initial enabled:true for dynamic object: \(id)")
        }

        // Always try to send transform data - let DynamicDataManager decide whether to record it
        // based on session state. This ensures no data is lost due to timing issues.
        await updateEntityTransform(entity, dynamicComponent: dynamicComponent, properties: properties)

        return shouldSendEnabledProperty
    }

    /// Update entity transform data and send to analytics system
    /// Uses component-specific thresholds rather than global defaults
    private func updateEntityTransform(
        _ entity: Entity,
        dynamicComponent: DynamicComponent,
        properties: [[String: AnyCodable]]?
    ) async {
        // Skip if no dynamic manager
        guard let dynamicManager = self.dynamicManager else {
            return
        }

        // Get world transform in one MainActor hop.
        let transform = await getWorldTransform(entity)

        // Use the existing recordDynamicObject method with component-specific thresholds
        // The timing control is now handled at the system level, so DynamicDataManager
        // focuses purely on threshold-based recording decisions
        await dynamicManager.recordDynamicObject(
            id: dynamicComponent.dynamicId,
            position: transform.position,
            rotation: transform.rotation,
            scale: transform.scale,
            positionThreshold: dynamicComponent.positionThreshold,
            rotationThreshold: dynamicComponent.rotationThreshold,
            scaleThreshold: dynamicComponent.scaleThreshold,
            updateRate: dynamicComponent.updateRate,
            properties: properties
        )
    }

    // Helper methods to safely access entity properties across actor boundaries
    private func captureEntityState(_ entity: Entity) async -> (dynamicComponent: DynamicComponent, isParentNil: Bool, isEntityActive: Bool)? {
        return await MainActor.run {
            guard let dynamicComponent = entity.components[DynamicComponent.self] else {
                return nil
            }
            return (dynamicComponent, entity.parent == nil, entity.isActive)
        }
    }

    private func getWorldTransform(_ entity: Entity) async -> (position: SIMD3<Float>, rotation: simd_quatf, scale: SIMD3<Float>) {
        return await MainActor.run {
            (
                position: entity.position(relativeTo: nil),
                rotation: entity.orientation(relativeTo: nil),
                scale: entity.scale(relativeTo: nil)
            )
        }
    }
}
