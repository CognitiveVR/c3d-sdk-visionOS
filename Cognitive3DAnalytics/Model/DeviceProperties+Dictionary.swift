//
//  DeviceProperties+Dictionary.swift
//  Cognitive3DAnalytics
//
//  Created on 2025-03-04.
//

import Foundation

extension DeviceProperties {
    // Convert DeviceProperties to dictionary
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "c3d.username": username,
            "c3d.app.name": appName,
            "c3d.app.version": appVersion,
            "c3d.app.engine.version": appEngineVersion,
            "c3d.device.type": deviceType,
            "c3d.device.cpu": deviceCPU,
            "c3d.device.model": deviceModel,
            "c3d.device.gpu": deviceGPU,
            "c3d.device.os": deviceOS,
            "c3d.device.memory": deviceMemory,
            "c3d.deviceid": deviceId,
            "c3d.roomsize": roomSize,
            "c3d.roomsizeDescription": roomSizeDescription,
            "c3d.app.inEditor": appInEditor,
            "c3d.version": version,
            "c3d.device.hmd.type": hmdType,
            "c3d.device.hmd.manufacturer": hmdManufacturer,
            "c3d.device.eyetracking.enabled": eyeTrackingEnabled,
            "c3d.device.eyetracking.type": eyeTrackingType,
            "c3d.app.sdktype": appSDKType,
            "c3d.app.engine": appEngine
        ]

        #if INCLUDE_HEIGHT_PROPERTY
        dict["c3d.height"] = height
        #endif

        return dict
    }

    // Create a DeviceProperties from a dictionary
    public static func fromDictionary(_ dict: [String: Any]) -> DeviceProperties? {
        guard
            let username = dict["c3d.username"] as? String,
            let appName = dict["c3d.app.name"] as? String,
            let appVersion = dict["c3d.app.version"] as? String,
            let appEngineVersion = dict["c3d.app.engine.version"] as? String,
            let deviceType = dict["c3d.device.type"] as? String,
            let deviceCPU = dict["c3d.device.cpu"] as? String,
            let deviceModel = dict["c3d.device.model"] as? String,
            let deviceGPU = dict["c3d.device.gpu"] as? String,
            let deviceOS = dict["c3d.device.os"] as? String,
            let deviceMemory = dict["c3d.device.memory"] as? Int,
            let deviceId = dict["c3d.deviceid"] as? String,
            let roomSize = dict["c3d.roomsize"] as? Double,
            let roomSizeDescription = dict["c3d.roomsizeDescription"] as? String,
            let appInEditor = dict["c3d.app.inEditor"] as? Bool,
            let version = dict["c3d.version"] as? String,
            let hmdType = dict["c3d.device.hmd.type"] as? String,
            let hmdManufacturer = dict["c3d.device.hmd.manufacturer"] as? String,
            let eyeTrackingEnabled = dict["c3d.device.eyetracking.enabled"] as? Bool,
            let eyeTrackingType = dict["c3d.device.eyetracking.type"] as? String,
            let appSDKType = dict["c3d.app.sdktype"] as? String,
            let appEngine = dict["c3d.app.engine"] as? String
        else {
            return nil
        }

        #if INCLUDE_HEIGHT_PROPERTY
        guard let height = dict["c3d.height"] as? Double else {
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
            deviceGPU: deviceGPU,
            deviceOS: deviceOS,
            deviceMemory: deviceMemory,
            deviceId: deviceId,
            roomSize: roomSize,
            roomSizeDescription: roomSizeDescription,
            appInEditor: appInEditor,
            version: version,
            hmdType: hmdType,
            hmdManufacturer: hmdManufacturer,
            eyeTrackingEnabled: eyeTrackingEnabled,
            eyeTrackingType: eyeTrackingType,
            appSDKType: appSDKType,
            appEngine: appEngine,
            height: height
        )
        #else
        return DeviceProperties(
            username: username,
            appName: appName,
            appVersion: appVersion,
            appEngineVersion: appEngineVersion,
            deviceType: deviceType,
            deviceCPU: deviceCPU,
            deviceModel: deviceModel,
            deviceGPU: deviceGPU,
            deviceOS: deviceOS,
            deviceMemory: deviceMemory,
            deviceId: deviceId,
            roomSize: roomSize,
            roomSizeDescription: roomSizeDescription,
            appInEditor: appInEditor,
            version: version,
            hmdType: hmdType,
            hmdManufacturer: hmdManufacturer,
            eyeTrackingEnabled: eyeTrackingEnabled,
            eyeTrackingType: eyeTrackingType,
            appSDKType: appSDKType,
            appEngine: appEngine
        )
        #endif
    }
}
