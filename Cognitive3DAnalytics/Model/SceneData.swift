//
//  SceneData.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The Scene Data gets used when posting to the C3D servers.
public class SceneData: Codable {
    public init(sceneName: String, sceneId: String, versionNumber: Int, versionId: Int) {
        self.sceneName = sceneName
        self.sceneId = sceneId
        self.versionNumber = versionNumber
        self.versionId = versionId
    }

    /// Descriptive name for the scene
    public var sceneName: String

    /// Unique identifier for the scene; this gets used when posting events.
    public var sceneId: String

    /// Numeric version for the scene
    public var versionNumber: Int

    /// Unique version ID set for the scene after being uploaded to a C3D server
    public var versionId: Int

    enum CodingKeys: String, CodingKey {
        case sceneName
        case sceneId = "id"
        case versionNumber
        case versionId
    }
}

/// Represents the scene manifest matching the provided JSON structure
public struct SceneManifest: Codable {
    public var createdAt: TimeInterval
    public var updatedAt: TimeInterval
    public var id: String
    public var versions: [SceneVersion]
    public var projectId: Int
    public var customerId: Int?
    public var sceneName: String
    public var isPublic: Bool
    public var hidden: Bool

    enum CodingKeys: String, CodingKey {
        case createdAt, updatedAt, id, versions, projectId, customerId, sceneName, isPublic, hidden
    }
}

/// Represents a version of a scene in the manifest
public struct SceneVersion: Codable {
    public var createdAt: TimeInterval
    public var updatedAt: TimeInterval
    public var id: Int
    public var sceneId: String
    public var versionNumber: Int
    public var scale: Double
    public var sdkVersion: String
    public var sceneFileType: String
    public var hasFixations: Bool
    public var isOptimized: Bool?
    public var dynamicsUpdateKey: String?

    enum CodingKeys: String, CodingKey {
        case createdAt, updatedAt, id, sceneId, versionNumber, scale, sdkVersion, sceneFileType, hasFixations, isOptimized, dynamicsUpdateKey
    }
}
