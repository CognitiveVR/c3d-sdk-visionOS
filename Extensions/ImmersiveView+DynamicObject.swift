//
//  ImmersiveView+DynamicObject.swift
//  Cognitive3D SDK Example
//
//  Created by Manjit Bedi on 2025-02-01.
//

import Cognitive3DAnalytics
import RealityKit
// The content created with RCP; currently, this is where the Dynamic object component is defined.
import RealityKitContent
import SwiftUI

typealias DynamicEntityPair = (entity: Entity, component: DynamicComponent)

/// ImmersiveView extension for dynamic objects handling
extension ImmersiveView {
    // MARK: C3D configure the dynamic objects in the scene
    /// This is a key method for using dynamic objects in the C3D SDK, it has 2 purposes:
    ///  * configure the dynamic objects
    ///  * associate the current scene with the gaze system which is required for ray casting
    ///
    ///  The registration of the dynamic objects use the custom `DynamicComponent` to obtain the required properties to use with the `DynamicDataManager`.
    ///  Note: ideally, a query would be done using the  `RealityKit` `Scene` but the scene instance is not known at this time.
    // TODO: refactor the approach to dynamic object registration to wait until the scene is known?
    @discardableResult
    func configureDynamicObjects(entity: Entity)-> [(entity: Entity, component: DynamicComponent)] {
        let core = Cognitive3DAnalyticsCore.shared

        guard let objManager = core.dynamicDataManager else {
            return []
        }

        // get a list of all the dynamic objects in the view hierarchy
        let dynamicEntities = findEntitiesWithComponent(entity, componentType: DynamicComponent.self)

        for (_, comp) in dynamicEntities {
            // Register each dynamic object with the C3D SDK.
            Task {
                await objManager.registerDynamicObject(id: comp.dynamicId, name: comp.name, mesh: comp.mesh)
            }
        }

        // TODO: test how this works when changing a USD scene.
        // This is needed to perform ray casts & collision detection with the gaze tracker.
        // If a gaze collides with a dynamic object, the dynamic object id gets added to the gaze record.
        if core.entity == nil {
            // we only want to do this once. This method can get called multiple times depending on how
            // dynamic objects are being created from a USD scene or in code.
            core.entity = entity
        }

        return dynamicEntities
    }
}
