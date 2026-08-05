//
//  DeviceProperties+Dictionary.swift
//  Cognitive3DAnalytics
//
//  Created on 2025-03-04.
//

import Foundation

extension DeviceProperties {
    // Convert DeviceProperties to dictionary.
    //
    // Keys are taken from `CodingKeys` rather than written out again as string literals, so the
    // dictionary form and the `Codable` form cannot drift apart. `DevicePropertiesTests` asserts
    // that every declared key is present here and that a round trip is lossless.
    public func toDictionary() -> [String: Any] {
        let dict: [String: Any] = [
            CodingKeys.username.rawValue: username,
            CodingKeys.appName.rawValue: appName,
            CodingKeys.appVersion.rawValue: appVersion,
            CodingKeys.appEngineVersion.rawValue: appEngineVersion,
            CodingKeys.deviceType.rawValue: deviceType,
            CodingKeys.deviceCPU.rawValue: deviceCPU,
            CodingKeys.deviceModel.rawValue: deviceModel,
            CodingKeys.deviceHardwareModel.rawValue: deviceHardwareModel,
            CodingKeys.deviceGPU.rawValue: deviceGPU,
            CodingKeys.deviceOS.rawValue: deviceOS,
            CodingKeys.deviceMemoryInGigabytes.rawValue: deviceMemoryInGigabytes,
            CodingKeys.deviceId.rawValue: deviceId,
            CodingKeys.roomSize.rawValue: roomSize,
            CodingKeys.roomSizeDescription.rawValue: roomSizeDescription,
            CodingKeys.appInEditor.rawValue: appInEditor,
            CodingKeys.isSimulator.rawValue: isSimulator,
            CodingKeys.version.rawValue: version,
            CodingKeys.hmdType.rawValue: hmdType,
            CodingKeys.hmdManufacturer.rawValue: hmdManufacturer,
            CodingKeys.eyeTrackingEnabled.rawValue: eyeTrackingEnabled,
            CodingKeys.eyeTrackingType.rawValue: eyeTrackingType,
            CodingKeys.appSDKType.rawValue: appSDKType,
            CodingKeys.appEngine.rawValue: appEngine
        ]

        return dict
    }

    // Create a DeviceProperties from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> DeviceProperties? {
        guard
            let username = dict[CodingKeys.username.rawValue] as? String,
            let appName = dict[CodingKeys.appName.rawValue] as? String,
            let appVersion = dict[CodingKeys.appVersion.rawValue] as? String,
            let appEngineVersion = dict[CodingKeys.appEngineVersion.rawValue] as? String,
            let deviceType = dict[CodingKeys.deviceType.rawValue] as? String,
            let deviceCPU = dict[CodingKeys.deviceCPU.rawValue] as? String,
            let deviceModel = dict[CodingKeys.deviceModel.rawValue] as? String,
            let deviceHardwareModel = dict[CodingKeys.deviceHardwareModel.rawValue] as? String,
            let deviceGPU = dict[CodingKeys.deviceGPU.rawValue] as? String,
            let deviceOS = dict[CodingKeys.deviceOS.rawValue] as? String,
            let deviceMemoryInGigabytes = dict[CodingKeys.deviceMemoryInGigabytes.rawValue] as? Int,
            let deviceId = dict[CodingKeys.deviceId.rawValue] as? String,
            let roomSize = dict[CodingKeys.roomSize.rawValue] as? Double,
            let roomSizeDescription = dict[CodingKeys.roomSizeDescription.rawValue] as? String,
            let appInEditor = dict[CodingKeys.appInEditor.rawValue] as? Bool,
            let isSimulator = dict[CodingKeys.isSimulator.rawValue] as? Bool,
            let version = dict[CodingKeys.version.rawValue] as? String,
            let hmdType = dict[CodingKeys.hmdType.rawValue] as? String,
            let hmdManufacturer = dict[CodingKeys.hmdManufacturer.rawValue] as? String,
            let eyeTrackingEnabled = dict[CodingKeys.eyeTrackingEnabled.rawValue] as? Bool,
            let eyeTrackingType = dict[CodingKeys.eyeTrackingType.rawValue] as? String,
            let appSDKType = dict[CodingKeys.appSDKType.rawValue] as? String,
            let appEngine = dict[CodingKeys.appEngine.rawValue] as? String
        else {
            return nil
        }

        return DeviceProperties(
            username: username,
            appName: appName,
            appVersion: appVersion,
            appEngineVersion: appEngineVersion,
            deviceType: deviceType,
            deviceCPU: deviceCPU,
            deviceModel: deviceModel,
            deviceHardwareModel: deviceHardwareModel,
            deviceGPU: deviceGPU,
            deviceOS: deviceOS,
            deviceMemoryInGigabytes: deviceMemoryInGigabytes,
            deviceId: deviceId,
            roomSize: roomSize,
            roomSizeDescription: roomSizeDescription,
            appInEditor: appInEditor,
            isSimulator: isSimulator,
            version: version,
            hmdType: hmdType,
            hmdManufacturer: hmdManufacturer,
            eyeTrackingEnabled: eyeTrackingEnabled,
            eyeTrackingType: eyeTrackingType,
            appSDKType: appSDKType,
            appEngine: appEngine
        )
    }
}
