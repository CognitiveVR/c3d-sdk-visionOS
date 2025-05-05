//
//  FixationInternal.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2024-12-02.
//

import Foundation
import simd

struct FixationInternal {
    // Used for all eye tracking
    var worldPosition: SIMD3<Float>
    var localPosition: SIMD3<Float>

    // Set when starting local fixation. Should hold last evaluated eye capture matrix
    // for a dynamic object (updated every frame)
    var dynamicMatrix: simd_double4x4

    // Only used for active session view visualization!
    var dynamicTransform: SIMD3<Float>  // Changed from Transform

    // Timestamp of last assigned valid eye capture. Used to 'timeout' from eyes closed
    var lastUpdated: Int64

    var durationMs: Int64
    var startMs: Int64

    var lastNonDiscardedTime: Int64
    var lastEyesOpen: Int64
    var lastInRange: Int64
    var lastOnTransform: Int64

    var startDistance: Float
    // Radius in meters that this fixation covers
    var maxRadius: Float
    var isLocal: Bool
    var dynamicObjectId: String
}
