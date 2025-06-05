//
//  DynamicObjectSystem.swift
//  Cognitive3D SDK Example
//
//  Created by Manjit Bedi on 2025-01-31.
//

import Cognitive3DAnalytics
import RealityKit
import RealityKitContent

/// This class works with the Dynamic object manager in the C3D SDK to record dynamic object data for the active analytics session.
public final class DynamicObjectSystem: System {
    // Query to find all entities with DynamicComponent
    private static let query = EntityQuery(where: .has(DynamicComponent.self))

    private enum EntityState {
        case disabled
        case enabledNeedsUpdate
        case enabledUpdated
    }

    // Dictionary to track entity states
    private var entityStates: [String: EntityState] = [:]

    // The dynamic object manager in the C3D SDK.
    private var dynamicManager: DynamicDataManager?

    var isDebugVerbose = false

    // Required initializer for RealityKit System
    public required init(scene: Scene) {
        guard let dynamicManager = Cognitive3DAnalyticsCore.shared.dynamicDataManager else {
            dynamicManager = nil
            return
        }

        self.dynamicManager = dynamicManager
    }

    // Using a system, record the transforms of dynamic objects. The data gets posted to the C3D servers.
    public func update(context: SceneUpdateContext) {
        Task {
            await processEntities(context: context)
        }
    }

    /// Get the position, scale & rotation for a entity to create a dynamic record to eventually post the C3D back end.
    private func processEntities(context: SceneUpdateContext) async {
        for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
            // Safely extract component information
            guard let dynamicComponent = await extractDynamicComponent(from: entity) else {
                continue
            }

            // Capture current entity state
            let isParentNil = await isEntityParentNil(entity)
            let isEntityActive = await checkEntityActive(entity)
            let isEnabled = !isParentNil && isEntityActive
            let id = dynamicComponent.dynamicId

            // Handle based on enabled state
            if !isEnabled {
                await handleDisabledEntity(entity, id: id)
                continue
            }

            await handleEnabledEntity(entity, dynamicComponent: dynamicComponent)
        }
    }

    /// Handle entity that is currently disabled
    private func handleDisabledEntity(_ entity: Entity, id: String) async {
        // Entity is now disabled
        let wasEnabled = await MainActor.run {
            let currentState = entityStates[id]
            let wasEnabled = currentState != .disabled && currentState != nil
            entityStates[id] = .disabled
            return wasEnabled
        }

        // If transitioning from enabled to disabled, remove from tracking
        if wasEnabled && dynamicManager != nil {
            if isDebugVerbose {
                print("Entity '\(await entity.name)' with dynamic ID \(id) is being removed from tracking.")
            }
            await dynamicManager?.removeDynamicObject(id: id)
        }
    }

    /// Handle entity that is currently enabled
    private func handleEnabledEntity(_ entity: Entity, dynamicComponent: DynamicComponent) async {
        let id = dynamicComponent.dynamicId

        // Check if properties update is needed
        let needsPropertyUpdate = await checkPropertyUpdateNeeded(id)

        // Only send properties when needed
        let properties: [[String: AnyCodable]]? = needsPropertyUpdate ?
            [["enabled": AnyCodable(true)]] : nil

        // Update transform data
        await updateEntityTransform(entity, dynamicComponent: dynamicComponent, properties: properties)
    }

    /// Check if this entity needs a property update and update state accordingly
    private func checkPropertyUpdateNeeded(_ id: String) async -> Bool {
        return await MainActor.run {
            let currentState = entityStates[id]

            if currentState == .disabled || currentState == nil {
                // Transitioning from disabled to enabled or new entity
                entityStates[id] = .enabledNeedsUpdate
                return true
            } else if currentState == .enabledNeedsUpdate {
                // Already enabled but needs update
                entityStates[id] = .enabledUpdated
                return true
            }

            // Already enabled and updated
            return false
        }
    }

    /// Update entity transform data and send to analytics system
    private func updateEntityTransform(_ entity: Entity, dynamicComponent: DynamicComponent, properties: [[String: AnyCodable]]?) async {
        // Get position and orientation in world space
        let position = await getWorldPosition(entity)
        let rotation = await getWorldRotation(entity)
        let scale = await getWorldScale(entity)

        // Create the data object that gets stored in the dynamic manager
        await dynamicManager?.recordDynamicObject(
            id: dynamicComponent.dynamicId,
            position: position,
            rotation: rotation,
            scale: scale,
            positionThreshold: dynamicComponent.positionThreshold,
            rotationThreshold: dynamicComponent.rotationThreshold,
            scaleThreshold: dynamicComponent.scaleThreshold,
            updateRate: dynamicComponent.updateRate,
            properties: properties
        )
    }

    // Helper methods to safely access entity properties across actor boundaries
    private func extractDynamicComponent(from entity: Entity) async -> DynamicComponent? {
        return await MainActor.run {
            entity.components[DynamicComponent.self]
        }
    }

    // MARK: - entity handling
    private func isEntityParentNil(_ entity: Entity) async -> Bool {
        return await MainActor.run {
            entity.parent == nil
        }
    }

    private func checkEntityActive(_ entity: Entity) async -> Bool {
        return await MainActor.run {
            entity.isActive
        }
    }

    // MARK: - transform handling to get world tranform values.
    // Get the world position of an entity
    private func getWorldPosition(_ entity: Entity) async -> SIMD3<Float> {
        let localPosition = await entity.position

        // If no parent, local position is world position
        guard let parent = await entity.parent else {
            return localPosition
        }

        // Get parent's world position
        let parentWorldPosition = await getWorldPosition(parent)
        let parentWorldRotation = await getWorldRotation(parent)
        let parentWorldScale = await getWorldScale(parent)

        // Apply parent's rotation to local position
        let rotatedPosition = parentWorldRotation.act(localPosition)

        // Apply parent's scale
        let scaledPosition = rotatedPosition * parentWorldScale

        // Add parent's position
        return parentWorldPosition + scaledPosition
    }

    // Get the world rotation of an entity
    private func getWorldRotation(_ entity: Entity) async -> simd_quatf {
        let localRotation = await entity.orientation

        // If no parent, local rotation is world rotation
        guard let parent = await entity.parent else {
            return localRotation
        }

        // Get parent's world rotation and multiply quaternions
        let parentWorldRotation = await getWorldRotation(parent)
        return parentWorldRotation * localRotation
    }

    // Get the world scale of an entity
    private func getWorldScale(_ entity: Entity) async -> SIMD3<Float> {
        let localScale = await entity.scale

        // If no parent, local scale is world scale
        guard let parent = await entity.parent else {
            return localScale
        }

        // Get parent's world scale and multiply
        let parentWorldScale = await getWorldScale(parent)
        return parentWorldScale * localScale
    }
}
