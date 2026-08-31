//
//  Utils.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2024-12-06.
//

import Foundation
import Metal
import RealityKit
import SwiftUI

/// Utility methods used by the C3D SDK.
public class Utils {
    // Helper to pretty print JSON
    public static func prettyPrintJSON(_ data: Any) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }
        return String(describing: data)
    }

    public static func prettyPrintPosition(_ position: [Double]) -> String {
        guard position.count >= 3 else { return "Invalid position" }
        return String(
            format: "⌖ [x: %.2f, y: %.2f, z: %.2f]",
            position[0],
            position[1],
            position[2]
        )
    }
}

// MARK: - Raw hardware signals
//
// The analytics SDK reports what the operating system says, verbatim. It does not translate,
// classify, or substitute device identities: any mapping from a raw identifier to a product name,
// device family, or hardware category belongs in the analytics pipeline, which is versioned and can
// be corrected after the fact. A value baked into a shipped SDK build can never be corrected for
// sessions that were already captured.
//
// Consequence: every function below returns "" when the operating system has no answer. An empty
// string means "this device did not report a value"; it must never be filled in with a guess.

/// Reads a `sysctl` string value by name and returns it verbatim.
///
/// - Parameter name: the `sysctl` key, for example `hw.model`.
/// - Returns: the raw string reported by the operating system, or `""` if the key is unavailable
///   on this platform or the lookup fails. The value is never translated or substituted.
func readSysctlString(_ name: String) -> String {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
        return ""
    }

    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
        return ""
    }

    return String(cString: buffer)
}

/// The raw `hw.model` hardware identifier, for example `N301AP` on Apple Vision Pro.
///
/// The board configuration. Reported together with `getRawHardwareMachineIdentifier()`; between them
/// the two identify the specific hardware variant, which no other reported signal does.
///
/// - Important: in a simulator build this reports the **host Mac's** hardware identifier, not a
///   headset. Consumers must read the simulator flag alongside it.
func getRawHardwareModel() -> String {
    return readSysctlString("hw.model")
}

/// The raw `hw.machine` device identifier, for example `RealityDevice14,1` on a first-generation
/// Apple Vision Pro.
///
/// A different `sysctl` from `hw.model`, and reported alongside it rather than instead of it. The two
/// answer different questions: `hw.model` is the board configuration (`N301AP`), while `hw.machine`
/// is the device identifier Apple documents and publishes for each hardware generation. Board
/// configurations for newly released hardware are frequently not public, so `hw.machine` is often
/// the only signal that can distinguish one generation from another — which is exactly what the
/// pipeline needs in order to tell hardware revisions apart.
///
/// - Important: in a simulator build this reports the **host Mac's** device identifier, not a
///   headset. Consumers must read the simulator flag alongside it.
func getRawHardwareMachineIdentifier() -> String {
    return readSysctlString("hw.machine")
}

/// The raw `machdep.cpu.brand_string` CPU identifier.
///
/// - Returns: the operating system's CPU brand string, or `""` when the key is not exposed. This
///   key is not available on every Apple platform; an empty value is the correct, honest report and
///   is preferable to substituting a hardcoded chip name. When it is empty, the hardware model
///   signal is what identifies the silicon.
/// - Important: in a simulator build this reports the **host Mac's** CPU, not the headset's.
func getRawCPUBrandString() -> String {
    return readSysctlString("machdep.cpu.brand_string")
}

/// The raw GPU name reported by Metal, for example `Apple M2 GPU`.
///
/// - Returns: `MTLDevice.name` verbatim, or `""` when no Metal device is available.
/// - Important: in a simulator build this reports the **host Mac's** GPU, not the headset's.
func getRawGPUName() -> String {
    return MTLCreateSystemDefaultDevice()?.name ?? ""
}

/// Whether this is a simulator build.
///
/// This is a compile-time fact about the build, not a runtime measurement, and is reported as a
/// plain boolean. Mapping it onto a runtime-host category is the pipeline's job.
let isSimulatorBuild: Bool = {
    #if targetEnvironment(simulator)
        return true
    #else
        return false
    #endif
}()

/// Number of bytes in one gigabyte, binary definition (1024³, strictly a gibibyte).
///
/// Named and applied explicitly so the unit is unambiguous at every call site.
let bytesPerGigabyte: UInt64 = 1_073_741_824

/// Process-lifetime cache of the hardware signals.
///
/// `createDeviceProperties(core:)` runs on every gaze batch. These values cannot change while the
/// process is alive, so the `sysctl` lookups and the Metal device creation are done once.
enum CachedRawDeviceSignals {
    static let hardwareModel = getRawHardwareModel()
    static let hardwareMachineIdentifier = getRawHardwareMachineIdentifier()
    static let cpuBrandString = getRawCPUBrandString()
    static let gpuName = getRawGPUName()
}

/// Method to get the applicaton display name. If there is no display name, the method returns the bundle name.
public func getAppDisplayName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(
        forInfoDictionaryKey: "CFBundleName"
    ) as! String
}

/// Total physical memory rounded down to whole gigabytes (1024³ bytes each).
func getTotalDeviceMemoryInGigabytes() -> Int {
    let totalMemoryInBytes = ProcessInfo.processInfo.physicalMemory
    return Int(totalMemoryInBytes / bytesPerGigabyte)
}

// TODO: review, implement height etc.
/// Get various properties for the application, device, and C3D SDK
///
/// Hardware values here are reported exactly as the operating system reports them. Turning a raw
/// identifier such as `N301AP` into a product name, family, or category is done downstream, not
/// here — see the "Raw hardware signals" section above.
func createDeviceProperties(core: Cognitive3DAnalyticsCore) -> DeviceProperties {
    let appName = getAppDisplayName()

    func getOperatingSystemVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "visionOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    // The device / model / HMD-type fields all carry the raw board configuration unchanged, rather
    // than three different hardcoded product names. The machine identifier is reported separately in
    // its own field; it is deliberately not substituted into these three, because changing what an
    // existing field carries would silently reinterpret sessions already captured under it.
    let hardwareModel = CachedRawDeviceSignals.hardwareModel

    // In visionOS, the app engine is the same as the operating system.
    return DeviceProperties(
        username: core.getParticipantFullName(),
        appName: appName,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        appEngineVersion: getOperatingSystemVersion(),
        deviceType: hardwareModel,
        deviceCPU: CachedRawDeviceSignals.cpuBrandString,
        deviceModel: hardwareModel,
        deviceHardwareModel: hardwareModel,
        deviceHardwareMachine: CachedRawDeviceSignals.hardwareMachineIdentifier,
        deviceGPU: CachedRawDeviceSignals.gpuName,
        deviceOS: getOperatingSystemVersion(),
        deviceMemoryInGigabytes: getTotalDeviceMemoryInGigabytes(),
        deviceId: core.getDeviceId(),
        roomSize: 0.0,
        roomSizeDescription: "Unknown",
        appInEditor: isSimulatorBuild,
        isSimulator: isSimulatorBuild,
        // The version of the analytics SDK.
        version: "\(Cognitive3DAnalyticsCore.version)",
        hmdType: hardwareModel,
        hmdManufacturer: "Apple",
        eyeTrackingEnabled: true,
        eyeTrackingType: "ARKit",
        appSDKType: "visionOS",
        appEngine: "visionOS"
    )
}

/**
 Finds all the entities with a specific component in the hierarchy.

 - Parameters:
   - entity: The root entity to start searching from.
   - componentType: The type of component to search for.
 - Returns: An array of tuples containing entities and their corresponding components.
 */
public func findEntitiesWithComponent<T: Component>(_ entity: Entity, componentType: T.Type) -> [(entity: Entity, component: T)] {
    var foundEntities: [(entity: Entity, component: T)] = []
    func searchEntities(_ currentEntity: Entity) {
        // Check if the entity has the specified component
        if let component = currentEntity.components[componentType] {
            foundEntities.append((entity: currentEntity, component: component))
        }

        // Recursively search children
        for child in currentEntity.children {
            searchEntities(child,)
        }
    }

    // Start the search
    searchEntities(entity)

    return foundEntities
}


// MARK: extensions
extension Entity {
    /// Recursively finds the first descendant (including self) with a ModelComponent.
    public func firstModelEntity() -> Entity? {
        if self.components[ModelComponent.self] != nil {
            return self
        }
        for child in self.children {
            if let found = child.firstModelEntity() {
                return found
            }
        }
        return nil
    }
}


extension Data {
    /// Attempts to format JSON data into a pretty-printed string representation
    ///
    /// - Parameters:
    ///   - options: JSONSerialization.WritingOptions to customize the output format (default includes .prettyPrinted)
    ///   - maxLines: Maximum number of lines to include in the output. Default is -1 (show all)
    ///              If positive, output will be truncated to the specified number of lines
    /// - Returns: A formatted string representation of the JSON data, potentially truncated
    /// - Throws: JSONError if the data cannot be parsed as JSON or formatted
    func prettyPrintedJSON(
        options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys],
        maxLines: Int = -1
    ) throws -> String {
        // First verify we have valid JSON data
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: .allowFragments) else {
            throw JSONError.invalidJSON
        }

        // Re-serialize with pretty printing
        let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: options)

        // Convert to string
        guard let prettyString = String(data: prettyData, encoding: .utf8) else {
            throw JSONError.stringConversionFailed
        }

        // Handle truncation if maxLines is specified
        if maxLines > 0 {
            let lines = prettyString.components(separatedBy: .newlines)
            if lines.count > maxLines {
                // Take first maxLines lines and add indication of truncation
                let truncated = lines.prefix(maxLines).joined(separator: "\n")
                return truncated + "\n... (truncated, \(lines.count - maxLines) more lines)"
            }
        }

        return prettyString
    }
}

// MARK: - String Formatting Extensions

extension AffineTransform3D {
    /// Formats transform for better readability by limiting decimal places
    func formattedDescription() -> String {
        // Extract the matrix elements with limited decimal places
        let description = String(describing: self)
        if let regex = try? NSRegularExpression(pattern: "(\\d+\\.\\d{2})\\d+") {
            let range = NSRange(description.startIndex..<description.endIndex, in: description)
            let modString = regex.stringByReplacingMatches(
                in: description,
                range: range,
                withTemplate: "$1"
            )
            return modString
        }
        return description
    }
}

// Helper extension for working with dictionaries
extension Dictionary where Key == String, Value == Any {
    // Add or update a property in the dictionary
    mutating func addProperty(key: String, value: Any) {
        self[key] = value
    }

    // Create new dictionary with added property
    func withProperty(key: String, value: Any) -> [String: Any] {
        var newDict = self
        newDict[key] = value
        return newDict
    }
}

// MARK: -

/// Custom errors for JSON formatting operations
enum JSONError: Error {
    case invalidJSON
    case stringConversionFailed

    var localizedDescription: String {
        switch self {
        case .invalidJSON:
            return "Failed to parse data as valid JSON"
        case .stringConversionFailed:
            return "Failed to convert formatted JSON data to string"
        }
    }
}



// MARK: - print format

func formatVector3D(_ position: SIMD3<Float>, useTwoDecimals: Bool = true) -> String {
    if useTwoDecimals {
        return String(format: "[%.2f, %.2f, %.2f]", position.x, position.y, position.z)
    } else {
        return String(format: "[%.3f, %.3f, %.3f]", position.x, position.y, position.z)
    }
}




