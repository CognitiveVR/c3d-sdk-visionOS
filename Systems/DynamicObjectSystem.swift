//
//  DynamicObjectSystem.swift
//  Cognitive3D SDK Example
//
//  Created by Manjit Bedi on 2025-01-31.
//

import RealityKit
import Cognitive3DAnalytics
import RealityKitContent

/// This class works with the Dynamic object manager in the C3D SDK to record dynamic object data for the active analytics session.
public final class DynamicObjectSystem: System {
    // Query to find all entities with DynamicComponent
    private static let query = EntityQuery(where: .has(DynamicComponent.self))
    private var inactiveStates: [String: Bool] = [:]
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
    
    // Using a system, update the transforms of dynamic objects. The data gets posted to the C3D servers.
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

            if isParentNil || !isEntityActive {
                await handleEnabledStateChange(entity, component: dynamicComponent)
                continue
            }

            // TODO: we don't need to send this every time. Only when the property has changed.
            let properties = [["enabled": AnyCodable(true)]]

            // Get position and orientation in world space
            let position = await getWorldPosition(entity)
            let rotation = await getWorldRotation(entity)
            let scale = await getWorldScale(entity)

            // Create the data object that gets stored in the dynamic manager to eventually
            // get posted to the C3D back end.
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

    // MARK: - entity state enabled (active)
    private func handleEnabledStateChange(_ entity: Entity, component: DynamicComponent) async {
        let isDisabled = await MainActor.run {
            !entity.isEnabled || !entity.isActive
        }
        
        if isDisabled {
            // Perform both check and update atomically on the MainActor
            let shouldRemove = await MainActor.run {
                // If not already inactive, mark as inactive and return true
                if inactiveStates[component.dynamicId] != true {
                    inactiveStates[component.dynamicId] = true
                    return true
                }
                return false
            }
            
            // Only remove if we successfully marked it as inactive
            if shouldRemove && dynamicManager != nil {
                if isDebugVerbose {
                    print("Entity '\(await entity.name)' with dynamic ID \(component.dynamicId) is being removed from tracking.")
                }
                await dynamicManager?.removeDynamicObject(id: component.dynamicId)
            }
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
