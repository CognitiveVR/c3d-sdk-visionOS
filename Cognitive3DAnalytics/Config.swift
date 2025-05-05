//
//  Config.swift
//  Cognitive3DAnalytics
//
//  Created by Calder Archinuk on 2024-11-18.
//
// Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The C3D Analytics works primarily with the GLTF file type.
public let gltfFileType = "gltf"

/// At this time, there is one HMD type running visonOS, the Apple Vision Pro.
public let visonProHmdType = "Vision Pro"

/// The C3D Analytics SDK format version.
public let analyticsFormatVersion1 = "1.0"

/// The Config class is used to set various parameters for the analytics SDK.
/// For example, the batch sizes limits  constrains when posts get posted to the back end as events get recorded.

public class Config {
    internal init() {

    }

    /// Scene data that has been uploaded to the back end.
    var allSceneData: [SceneData] = []

    /// The head mounted display type.
    var hmdType: String = ""

    ///  The Application API key is set by the application that has integrated the C3D analytics framework.
    var applicationKey: String = ""

    var gazeBatchSize: Int = 256
    var fixationBatchSize: Int = 128
    var customEventBatchSize: Int = 64
    var sensorDataLimit: Int = 128
    var dynamicDataLimit: Int = 128

    /// The type for objects that get uploaded, at this time there is no native support for GLTF in visonOS.
    var dynamicObjectFileType: String = gltfFileType

    /// The frequency at which gaze events get recorded.
    var gazeInterval: Float = 0.2

    /// Controls if the recorded coordinates need to be converted; visionOS is right handed.
    var targetCoordinateSystem: CoordinateSystem = .leftHanded

    /// Controls whether FPS data should be recorded during sessions.
    var isRecordingFPS: Bool = true

    /// Controls whether headset pitch data should be recorded during sessions.
    var isRecordingPitch: Bool = true

    /// Controls whether headset yaw data should be recorded during sessions.
    var isRecordingYaw: Bool = true

    /// Controls whether battery levels should be recorded during sessions.
    var isRecordingBatteryLevel: Bool = true

    /// Controls whether the gaze direction should be rotated 180 degrees around the Y axis
    /// This is a result of exporting a USDZ file then bringing into Blender and then exporting a GLTF.
    @available(*, deprecated, message: "This hack does not work correctly; instead make changes in the content creation of the USDZ file for converting to a GLTF scene.")
    var shouldRotateGaze180: Bool = false

    /// The raycast length for the gaze direction when doing collision detection
    public var raycastLength: Float = 10.0

    /// Set to true to end sessions when the idle threshold is passed.
    public var shouldEndSessionOnIdle: Bool = false

    /// Idle time out threshold
    public var idleThreshold: TimeInterval = 10.0

    /// Set this to true to send any recorded data when the app has the `inActive` scenePhase
    public var shouldSendDataOnInactive = true

    /// Set this to true such that the analytics SDK will end a session when the app has entered the `background` scenePhase.
    public var shouldEndSessionOnBackground = false

    /// If the Internet connection becomes unavailable & there is data to send later this can be used to monitor the Internconenctivity.
    public var useSyncServices = false
}
