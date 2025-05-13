//
//  ProxyDynamicObjectsModel.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-04-09.
//

import Foundation
import RealityKit
import SwiftUI

/// Data model for working with proxy dynamic objects.
/// An application will have at least one window with a SwiftUI view in it's content.
@MainActor
@Observable
public class ProxyDynamicObjectsModel {
    // MARK: - View Tracking Properties
    /// Geometry readers from content views for accessing 3D coordinates
    public var viewGeometries: [String: GeometryProxy3D] = [:]

    /// Window position data  model for persisting window position and size
    public var viewModels: [String: ViewPositionModel] = [:]

    // an empty initializer is required for use in a framework.
    public init() {}
}
