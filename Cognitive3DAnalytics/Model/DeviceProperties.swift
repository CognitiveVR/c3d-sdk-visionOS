//
//  DeviceProperties.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//

import Foundation

/// Information regarding the device, app & user etc.
public struct DeviceProperties: Codable {
    let username: String
    let appName: String
    let appVersion: String
    let appEngineVersion: String
    let deviceType: String
    let deviceCPU: String
    let deviceModel: String
    let deviceGPU: String
    let deviceOS: String
    let deviceMemory: Int
    let deviceId: String
    let roomSize: Double
    let roomSizeDescription: String
    let appInEditor: Bool
    let version: String
    let hmdType: String
    let hmdManufacturer: String
    let eyeTrackingEnabled: Bool
    let eyeTrackingType: String
    let appSDKType: String
    let appEngine: String

    enum CodingKeys: String, CodingKey {
        case username = "c3d.username"
        case appName = "c3d.app.name"
        case appVersion = "c3d.app.version"
        case appEngineVersion = "c3d.app.engine.version"
        case deviceType = "c3d.device.type"
        case deviceCPU = "c3d.device.cpu"
        case deviceModel = "c3d.device.model"
        case deviceGPU = "c3d.device.gpu"
        case deviceOS = "c3d.device.os"
        case deviceMemory = "c3d.device.memory"
        case deviceId = "c3d.deviceid"
        case roomSize = "c3d.roomsize"
        case roomSizeDescription = "c3d.roomsizeDescription"
        case appInEditor = "c3d.app.inEditor"
        case version = "c3d.version"
        case hmdType = "c3d.device.hmd.type"
        case hmdManufacturer = "c3d.device.hmd.manufacturer"
        case eyeTrackingEnabled = "c3d.device.eyetracking.enabled"
        case eyeTrackingType = "c3d.device.eyetracking.type"
        case appSDKType = "c3d.app.sdktype"
        case appEngine = "c3d.app.engine"
    }
}
