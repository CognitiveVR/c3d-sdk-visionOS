//
//  DynamicObjectConfig.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Dynamic object configuration
public struct DynamicObjectConfig {
    var dynamicId: String
    var name: String
    var mesh: String
    var syncWithGaze: Bool
    var updateRate: Float
    var positionThreshold: Float
    var rotationThreshold: Float
    var scaleThreshold: Float

    public init(
        dynamicId: String,
        name: String,
        mesh: String,
        syncWithGaze: Bool = true,
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
