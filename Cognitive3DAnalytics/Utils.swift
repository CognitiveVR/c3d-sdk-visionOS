//
//  Utils.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2024-12-06.
//

import Foundation
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

// TODO: refactor, is there a better way to get the AVP CPU type?
func getDeviceChipInfo() -> String {
    // Try CPU brand string first
    var size = 0
    var buffer: [CChar]

    // Try machdep.cpu.brand_string
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    if size > 0 {
        buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 {
            let result = String(cString: buffer)
            if result != "" {
                return result
            }
        }
    }

    // Try hw.model if CPU brand string fails
    size = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    if size > 0 {
        buffer = [CChar](repeating: 0, count: size)
        if sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 {
            let model = String(cString: buffer)

            // Translate known model identifiers
            switch model {
            case "N301AP":
                return "Apple Vision Pro (M2)"
            default:
                if model.starts(with: "N301") {
                    return "Apple Vision Pro (M2)"
                }
                return model
            }
        }
    }

    // Fallback with platform-specific default
    #if os(visionOS)
        return "Apple Vision Pro (M2)"
    #else
        return "Unknown Apple Device"
    #endif
}

/// Method to get the applicaton display name. If there is no display name, the method returns the bundle name.
public func getAppDisplayName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(
        forInfoDictionaryKey: "CFBundleName"
    ) as! String
}

// TODO: review, implement height etc.
/// Get various properties for the application, device, and C3D SDK
func createDeviceProperties(core: Cognitive3DAnalyticsCore) -> DeviceProperties {
    // Determine simulator status before the initialization
    let isInSimulator: Bool = {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }()

    let cpu = getDeviceChipInfo()

    let appName = getAppDisplayName()

    func getOperatingSystemVersion() -> String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "visionOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }

    func getTotalDeviceMemory() -> Int {
        // Get the total physical memory in bytes
        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        return Int(totalMemoryBytes)
    }

    func getTotalDeviceMemoryGB() -> Int {
        // Get the total physical memory in bytes
        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory

        // Convert bytes to gigabytes using system-specific divisor
        return Int(totalMemoryBytes / 1_027_376_128)
    }

    // In visionOS, the app engine is the same as the operating system.
    return DeviceProperties(
        username: core.getParticipantFullName(),
        appName: appName,
        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        appEngineVersion: getOperatingSystemVersion(),
        deviceType: "Apple Vision Pro",
        deviceCPU: cpu,
        deviceModel: visonProHmdType,
        deviceGPU: "Apple GPU",
        deviceOS: getOperatingSystemVersion(),
        deviceMemory: getTotalDeviceMemoryGB(),
        deviceId: core.getDeviceId(),
        roomSize: 0.0,
        roomSizeDescription: "Unknown",
        appInEditor: isInSimulator,  // Use the pre-computed value
        // The version of the analytics SDK.
        version: "\(Cognitive3DAnalyticsCore.version)",
        hmdType: visonProHmdType,
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




