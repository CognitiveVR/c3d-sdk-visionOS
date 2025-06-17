//
//  HandComponent.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-05-16.
//

import Foundation
import RealityKit

public struct HandComponent: Component, Codable, Sendable {

    public var dynamicId: String = ""

    public var name: String = ""

    public var mesh: String = ""

    /// Causes this Dynamic Object to record data on the same interval as Gaze. For example, if the participant is in a vehicle, this can make movement appear smoother on SceneExplorer.
    public var syncWithGaze: Bool = false

    /// How frequently this dynamic object will check if it has moved/rotated/scaled beyond a threshold and should record its new transformation.
    public var updateRate: Float = 0.1

    ///  Meters the object must move to record new data.
    public var positionThreshold: Float = 0.01

    ///  Degrees the object must rotate to record new data.
    public var rotationThreshold: Float = 0.1

    /// Percent the object must scale to record new data.
    public var scaleThreshold: Float = 0.1

    public init() {}

    public init(
        dynamicId: String = "",
        name: String = "",
        mesh: String = "",
        syncWithGaze: Bool = false,
        updateRate: Float = 0.1,
        positionThreshold: Float = 0.01,
        rotationThreshold: Float = 0.1,
        scaleThreshold: Float = 0.1
    ) {
        self.dynamicId = dynamicId
        self.name = name
        self.mesh = mesh
        self.syncWithGaze = syncWithGaze
        self.updateRate = updateRate
        self.positionThreshold = positionThreshold
        self.rotationThreshold = rotationThreshold
        self.scaleThreshold = scaleThreshold
    }
}

