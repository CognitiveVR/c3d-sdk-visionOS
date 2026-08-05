//
//  DeviceProperties.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//

import Foundation

/// Information regarding the device, app & user etc.
///
/// - Note: this type is kept in step with `DeviceProperties+Dictionary.swift` by
///   `DevicePropertiesTests`, which asserts that the dictionary produced by `toDictionary()`
///   carries exactly the keys declared in `CodingKeys` and that a dictionary round trip is
///   lossless. Adding a stored property here without wiring it into **both** directions of that
///   extension will turn those tests red.
public struct DeviceProperties: Codable {
    let username: String
    let appName: String
    let appVersion: String
    let appEngineVersion: String
    /// Raw hardware identifier reported by the operating system, unclassified.
    let deviceType: String
    /// Raw CPU brand string, or `""` when the operating system does not expose one.
    let deviceCPU: String
    /// Raw hardware identifier reported by the operating system, unclassified.
    let deviceModel: String
    /// Raw `hw.model` hardware identifier, for example `N301AP`. The signal used downstream to
    /// resolve the specific hardware variant.
    let deviceHardwareModel: String
    /// Raw GPU name reported by Metal, or `""` when no Metal device is available.
    let deviceGPU: String
    let deviceOS: String
    /// Total physical memory in whole gigabytes (1024³ bytes each), rounded down.
    let deviceMemoryInGigabytes: Int
    let deviceId: String
    let roomSize: Double
    let roomSizeDescription: String
    /// Retained for compatibility with existing consumers. On this platform it carries the same
    /// value as `isSimulator`; prefer `isSimulator`, whose name matches what is measured.
    let appInEditor: Bool
    /// Whether this is a simulator build. In a simulator build the hardware signals above describe
    /// the host Mac, not a headset.
    let isSimulator: Bool
    let version: String
    /// Raw hardware identifier reported by the operating system, unclassified.
    let hmdType: String
    let hmdManufacturer: String
    let eyeTrackingEnabled: Bool
    let eyeTrackingType: String
    let appSDKType: String
    let appEngine: String

    enum CodingKeys: String, CodingKey, CaseIterable {
        case username = "c3d.username"
        case appName = "c3d.app.name"
        case appVersion = "c3d.app.version"
        case appEngineVersion = "c3d.app.engine.version"
        case deviceType = "c3d.device.type"
        case deviceCPU = "c3d.device.cpu"
        case deviceModel = "c3d.device.model"
        case deviceHardwareModel = "c3d.device.hw_model"
        case deviceGPU = "c3d.device.gpu"
        case deviceOS = "c3d.device.os"
        case deviceMemoryInGigabytes = "c3d.device.memory"
        case deviceId = "c3d.deviceid"
        case roomSize = "c3d.roomsize"
        case roomSizeDescription = "c3d.roomsizeDescription"
        case appInEditor = "c3d.app.inEditor"
        case isSimulator = "c3d.device.isSimulator"
        case version = "c3d.version"
        case hmdType = "c3d.device.hmd.type"
        case hmdManufacturer = "c3d.device.hmd.manufacturer"
        case eyeTrackingEnabled = "c3d.device.eyetracking.enabled"
        case eyeTrackingType = "c3d.device.eyetracking.type"
        case appSDKType = "c3d.app.sdktype"
        case appEngine = "c3d.app.engine"
    }
}
