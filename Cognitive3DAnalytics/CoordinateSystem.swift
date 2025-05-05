//
//  CoordinateSystem.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-13.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Defines different coordinate system conventions
public enum CoordinateSystem {
    case visionOS   // Right-handed: X right, Y up, -Z forward
    case leftHanded // Left-handed:  X right, Y up, +Z forward

    // TODO: convert to using float instead of double, simd types are float
    // There are many representations for vector points in visionOS - which is the one to standardize on?
    func convertPosition(_ position: [Double], rotateGaze180: Bool = false) -> [Double] {
        guard position.count >= 3 else { return position }

        var result: [Double]
        switch self {
        case .visionOS:
            result = position // No conversion needed, native format
        case .leftHanded:
            result = [
                position[0],   // X stays the same (right)
                position[1],   // Y stays the same (up)
                -position[2]   // Z is inverted (forward direction flip)
            ]
        }

        // Apply 180-degree Y rotation if needed
        if rotateGaze180 {
            result = [
                -result[0],  // Flip X
                result[1],   // Y stays the same
                -result[2]   // Flip Z
            ]
        }

        return result
    }

    func convertRotation(_ rotation: [Double], rotateGaze180: Bool = false) -> [Double] {
        guard rotation.count >= 4 else { return rotation }

        var result: [Double]
        switch self {
        case .visionOS:
            result = rotation // No conversion needed, native format
        case .leftHanded:
            result = [
                rotation[0],    // x component stays the same
                rotation[1],    // y component stays the same
                -rotation[2],   // z component is negated
                -rotation[3]    // w component is negated
            ]
        }

        // Apply 180-degree Y rotation if needed
        if rotateGaze180 {
            result = [
                -result[0],  // Flip X quaternion component
                result[1],   // Y stays the same
                -result[2],  // Flip Z quaternion component
                result[3]    // W stays the same for 180-degree rotation
            ]
        }

        return result
    }
}
