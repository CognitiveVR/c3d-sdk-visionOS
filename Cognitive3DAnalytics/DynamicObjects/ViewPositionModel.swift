//
//  ViewPositionModel.swift
//  Cognitive3DAnalytics
//

import SwiftUI
import RealityKit

/// Model to track and store information about a window's position and size this is used with dynamic objects.
/// This class also provides methods to convert between points and Metric.  The SwiftUI views are using points (pixels).
@Observable
public class ViewPositionModel {
    // MARK: - Properties
    // Time of last update
    public var lastUpdateTime: Date = Date()

    // Debugging information as formatted text
    public var debugInfo: String = "No data yet"

    /// SwiftUI view transform
    public var transform: AffineTransform3D? = nil

    /// View Position
    public var position = SIMD3<Float>(0, 0, 0)

    /// View Size
    public var size = SIMD3<Float>(0, 0, 0)

    /// Magic number to adjust the size of the entity when being converted from points to Metric.
    // TODO: refactor - what is the correct way to do this?
    var adjustmentFactor: Float = 2.0

    /// Validation property to check if model has complete data
    var isDataComplete: Bool {
        return transform != nil && size != SIMD3<Float>(0, 0, 0)
    }

    // MARK: - Update Methods

    /// Update all model information
    func updateInfo(_ info: String, position: SIMD3<Float>, quaternion: simd_quatd?, size: SIMD3<Float>) {
        debugInfo = info
        self.position = position
        self.size = size
        lastUpdateTime = Date()
    }

    // MARK: - Entity Transform Methods

    /// Apply all transformations to an entity in one coordinated operation
    public func applyTransformsToEntity(_ entity: ModelEntity,
                               using metricsConverter: PhysicalMetricsConverter,
                               geometry: GeometryProxy3D?,
                               useOffset: Bool = true) {
        // Apply each transform component
        applyPosition(to: entity, using: metricsConverter, useOffset: useOffset)
        applyScale(to: entity, using: metricsConverter, geometry: geometry)
        applyRotation(to: entity)
    }

    /// Apply position transformation to entity
    public func applyPosition(to entity: ModelEntity,
                     using metricsConverter: PhysicalMetricsConverter,
                     useOffset: Bool = true) {
        guard let transform = self.transform else { return }

        let simdPosition = SIMD3<Float>(
            Float(transform.translation.x),
            Float(transform.translation.y),
            Float(transform.translation.z)
        )

        let convertedPosition = convertPositionToMetric(simdPosition,
                                                     using: metricsConverter,
                                                     size: size,
                                                     useOffset: useOffset)

        entity.position = convertedPosition
    }

    /// Apply scale transformation to entity using geometry if available
    public func applyScale(to entity: ModelEntity,
                  using metricsConverter: PhysicalMetricsConverter,
                  geometry: GeometryProxy3D?) {
        // Use geometry for size if available, otherwise use model size
        let sizeToUse = getSizeFrom(geometry) ?? size
        let finalScale = calculateScale(from: sizeToUse, using: metricsConverter)
        entity.scale = finalScale
    }

    /// Apply rotation transformation to entity
    public func applyRotation(to entity: ModelEntity) {
        guard let transform = self.transform else { return }

        if let quaternion = transform.rotation?.quaternion {
            let quatF = simd_quatf(
                ix: Float(quaternion.imag.x),
                iy: Float(quaternion.imag.y),
                iz: Float(quaternion.imag.z),
                r: Float(quaternion.real)
            )

            let worldSpaceCorrection = simd_quatf(angle: Float.pi, axis: [0, 1, 0])
            entity.transform.rotation = worldSpaceCorrection * quatF
        }
    }

    // MARK: - Helper Methods

    /// Extract size from geometry proxy
    private func getSizeFrom(_ geometry: GeometryProxy3D?) -> SIMD3<Float>? {
        guard let geometry = geometry else { return nil }

        return SIMD3<Float>(
            Float(geometry.size.width),
            Float(geometry.size.height),
            Float(geometry.size.depth)
        )
    }

    /// Calculate scale based on size and conversion
    private func calculateScale(from size: SIMD3<Float>,
                             using converter: PhysicalMetricsConverter) -> SIMD3<Float> {
        let compensatedConverter = converter.worldScalingCompensation(.unscaled)

        let widthInPoints = Double(size.x)
        let heightInPoints = Double(size.y)

        let widthInMeters = compensatedConverter.convert(widthInPoints, to: .meters)
        let heightInMeters = compensatedConverter.convert(heightInPoints, to: .meters)

        return SIMD3<Float>(
            abs(Float(widthInMeters) * adjustmentFactor),
            abs(Float(heightInMeters) * adjustmentFactor),
            0.025
        )
    }

    /// Convert points from SwiftUI coordinate system to RealityKit metric space
    func convertPointsToMetric(_ vector: SIMD3<Float>,
                             using converter: PhysicalMetricsConverter) -> SIMD3<Float> {
        let point3D = Point3D(x: vector.x, y: vector.y, z: vector.z)
        let adjustedPosition = converter.convert(point3D, to: .meters)

        return SIMD3<Float>(
            Float(adjustedPosition.x),
            -Float(adjustedPosition.y),
            Float(adjustedPosition.z)
        )
    }

    /// Convert sizes from points to metric
    func convertSizeToMetric(_ vector: SIMD3<Float>,
                           using converter: PhysicalMetricsConverter) -> SIMD3<Float> {
        let point3D = Point3D(x: vector.x, y: vector.y, z: vector.z)
        let adjustedSize = converter.worldScalingCompensation(.scaled).convert(point3D, to: .meters)

        return SIMD3<Float>(
            abs(Float(adjustedSize.x)),
            abs(Float(adjustedSize.y)),
            abs(Float(adjustedSize.z))
        )
    }

    /// Convert position with optional offset to account for anchor point differences
    func convertPositionToMetric(_ vector: SIMD3<Float>,
                               using converter: PhysicalMetricsConverter,
                               size: SIMD3<Float>,
                               useOffset: Bool) -> SIMD3<Float> {
        let convertedPosition = convertPointsToMetric(vector, using: converter)

        if !useOffset {
            return convertedPosition
        }

        let convertedSize = convertSizeToMetric(size, using: converter)
        let adjustedSize = SIMD3<Float>(
            convertedSize.x * adjustmentFactor,
            convertedSize.y * adjustmentFactor,
            convertedSize.z
        )

        return SIMD3<Float>(
            convertedPosition.x + (adjustedSize.x / 2.0),
            // Coordinate space conversion from top left origin hence the -ve
            convertedPosition.y - (adjustedSize.y / 2.0),
            convertedPosition.z
        )
    }
}
