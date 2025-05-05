//
//  CoreSettings.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-12-04.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The `CoreSettings` class contains various settings that are used to configure the C3D SDK at run-time.
// TODO: compare the use of config class & settings class. Can they be combined into one class?
public class CoreSettings {

    /// Metadata for the scene name.
    public var defaultSceneName: String = ""

    public var allSceneData: [SceneData] = []
    
    public var apiKey: String = ""

    public var loggingLevel: LogLevel = .all

    public var isDebugVerbose: Bool = false
    
    public var hmdType: String = ""

    public var gazeBatchSize: Int = 64

    public var customEventBatchSize: Int = 64

    public var sensorDataLimit: Int = 64

    public var dynamicDataLimit: Int = 64

    public var gazeInterval: Double = 0.1

    /// At this time, the SDK works with GLTF files, other file type may be supported in the future.
    public var dynamicObjectFileType: String = gltfFileType

    /// Fixation batch size - currently unused
    public var fixationBatchSize: Int = 64

    /// Set this to true to activate network connectivity monitoring and offline data handling.
    public var isOfflineSupportEnabled: Bool = true

    /// Enable network request logging
    public var isNetworkLoggingEnabled: Bool = false

    /// Maximum number of network request records to keep
    public var networkLogMaxRecords: Int = 100

    /// Enable verbose network logging
    public var isNetworkLoggingVerbose: Bool = false

    public init(
        defaultSceneName: String = "",
        allSceneData: [SceneData] = [],
        apiKey: String = "",
        loggingLevel: LogLevel = .all,
        isDebugVerbose: Bool = false,
        hmdType: String = "",
        gazeBatchSize: Int = 64,
        customEventBatchSize: Int = 64,
        sensorDataLimit: Int = 64,
        dynamicDataLimit: Int = 64,
        gazeInterval: Double = 0.1,
        dynamicObjectFileType: String = "GLTF",
        fixationBatchSize: Int = 64,
        isOfflineSupportEnabled: Bool = true
    ) {
        self.defaultSceneName = defaultSceneName
        self.allSceneData = allSceneData
        self.apiKey = apiKey
        self.loggingLevel = loggingLevel
        self.isDebugVerbose = isDebugVerbose
        self.hmdType = hmdType
        self.gazeBatchSize = gazeBatchSize
        self.customEventBatchSize = customEventBatchSize
        self.sensorDataLimit = sensorDataLimit
        self.dynamicDataLimit = dynamicDataLimit
        self.gazeInterval = gazeInterval
        self.dynamicObjectFileType = dynamicObjectFileType
        self.fixationBatchSize = fixationBatchSize
        self.isOfflineSupportEnabled = isOfflineSupportEnabled
    }
}
