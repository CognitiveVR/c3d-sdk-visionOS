//
//  DynamicComponent.swift
//  Cognitive3D SDK
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import RealityKit
import Cognitive3DAnalytics

/// The DynamicComponent is used for the dynamic objects feature in the C3D analytics SDK for Swift.
// TODO: change this to inherhit from a class defined in the C3D SDK?
// Ensure you register this component in your app’s delegate using:
// DynamicComponent.registerComponent()
public struct DynamicComponent: Component, Codable {
    // This ID corresponds the ID used in C3D web app to associate events & gazes with entities in a scene.
    public var dynamicId: String = ""

    public var name: String = ""

    public var mesh: String = ""

    /// Causes this Dynamic Object to record data on the same interval as Gaze. For example, if the participant is in a vehicle, this can make movement appear smoother on SceneExplorer.
    public var syncWithGaze: Bool = true

    /// How frequently this dynamic object will check if it has moved/rotated/scaled beyond a threshold and should record its new transformation.
    public var updateRate: Float = 0.1

    ///  Meters the object must move to record new data.
    public var positionThreshold: Float = 0.01

    ///  Degrees the object must rotate to record new data.
    public var rotationThreshold: Float = 0.1

    /// Percent the object must scale to record new data.
    public var scaleThreshold: Float = 0.1

    public init() {

    }
}
