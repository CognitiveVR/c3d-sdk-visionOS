//
//  SimdUtility.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import simd
import RealityKit

/// Useful extensions to the SIMD3 type.
extension SIMD3 where Scalar == Float {
    var normalized: Self {
        let length = sqrt(x*x + y*y + z*z)
        guard length > 0 else { return self }
        return self / length
    }

    var xyz: Self {
        self
    }

    func toDouble() -> [Double] {
        [Double(x), Double(y), Double(z)]
    }

    // Get direction vector from one point to another
    func direction(to target: SIMD3<Float>) -> SIMD3<Float> {
        (target - self).normalized
    }

    // Scale vector by distance
    func scaled(by distance: Float) -> SIMD3<Float> {
        self.normalized * distance
    }
}

extension SIMD4 where Scalar == Float {
    public var xyz: SIMD3<Scalar> {
        SIMD3(x: x, y: y, z: z)
    }

    func toDouble() -> [Double] {
        [Double(x), Double(y), Double(z), Double(w)]
    }
}

extension simd_float4x4 {
    var position: SIMD3<Float> {
        columns.3.xyz
    }

    var forward: SIMD3<Float> {
        -columns.2.xyz.normalized  // Note the negative sign
    }

    var right: SIMD3<Float> {
        columns.0.xyz.normalized
    }

    var up: SIMD3<Float> {
        columns.1.xyz.normalized
    }

    var rotationMatrix: simd_float3x3 {
        simd_float3x3(
            columns.0.xyz,
            columns.1.xyz,
            columns.2.xyz
        )
    }
}

extension simd_quatf {
    // Convert quaternion to Euler angles (in radians)
    var eulerAngles: SIMD3<Float> {
        let x = atan2(2.0 * (real * vector.x + vector.y * vector.z),
                     1.0 - 2.0 * (vector.x * vector.x + vector.y * vector.y))
        let y = asin(2.0 * (real * vector.y - vector.z * vector.x))
        let z = atan2(2.0 * (real * vector.z + vector.x * vector.y),
                     1.0 - 2.0 * (vector.y * vector.y + vector.z * vector.z))
        return SIMD3<Float>(x, y, z)
    }

    // Get forward direction vector from quaternion
    var forward: SIMD3<Float> {
        let rotationMatrix = simd_matrix3x3(self)
        return -normalize(SIMD3<Float>(rotationMatrix.columns.2))
    }
}

extension SIMD4 {
   var xyz: SIMD3<Scalar> {
       SIMD3(x, y, z)
   }
}
