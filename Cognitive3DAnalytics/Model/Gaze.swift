//
//  Gaze.swift
//  Cognitive3DAnalytics
//
//  Created by Cognitive3D on 2024-12-02.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Gaze data model - direction of eye where user is looking
public struct Gaze: Codable {
    /// Unique identifier for the user
    public let userId: String

    /// Time stamp for when the session started
    public let timestamp: Double

    ///  Unique id for the session
    public let sessionId: String

    /// The part number gets incremented every time a post is made.
    public let part: Int

    /// version style for the JSON data
    public let formatVersion: String

    /// head mount display (HMD) type
    public let hmdType: String

    /// interval
    public let interval: Double

    /// properties
    public let properties: [String: Any]

    /// Gaze event data
    public let data: [GazeEventData]

    private enum CodingKeys: String, CodingKey {
        case formatVersion = "formatversion"
        case sessionId = "sessionid"
        case userId = "userid"
        case hmdType = "hmdtype"
        case data
        case part
        case timestamp
        case interval
        case properties
    }

    // Custom initializer
    public init(userId: String, timestamp: Double, sessionId: String, part: Int, formatVersion: String,
                hmdType: String, interval: Double, properties: [String: Any], data: [GazeEventData]) {
        self.userId = userId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.part = part
        self.formatVersion = formatVersion
        self.hmdType = hmdType
        self.interval = interval
        self.properties = properties
        self.data = data
    }

    // MARK: - Codable implementation

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(formatVersion, forKey: .formatVersion)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encode(hmdType, forKey: .hmdType)
        try container.encode(data, forKey: .data)
        try container.encode(part, forKey: .part)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(interval, forKey: .interval)

        // For properties, encode each property directly into the properties container
        var propertiesContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .properties)

        for (key, value) in properties {
            let codingKey = DynamicCodingKey(stringValue: key)

            if let boolValue = value as? Bool {
                try propertiesContainer.encode(boolValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try propertiesContainer.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try propertiesContainer.encode(doubleValue, forKey: codingKey)
            } else if let stringValue = value as? String {
                try propertiesContainer.encode(stringValue, forKey: codingKey)
            }
            // Only handle the basic types: string, boolean, numeric
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        userId = try container.decode(String.self, forKey: .userId)
        timestamp = try container.decode(Double.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        part = try container.decode(Int.self, forKey: .part)
        formatVersion = try container.decode(String.self, forKey: .formatVersion)
        hmdType = try container.decode(String.self, forKey: .hmdType)
        interval = try container.decode(Double.self, forKey: .interval)
        data = try container.decode([GazeEventData].self, forKey: .data)

        // Decode properties as a dictionary
        let propertiesContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .properties)
        var propsDict: [String: Any] = [:]

        for key in propertiesContainer.allKeys {
            if let boolValue = try? propertiesContainer.decode(Bool.self, forKey: key) {
                propsDict[key.stringValue] = boolValue
            } else if let intValue = try? propertiesContainer.decode(Int.self, forKey: key) {
                propsDict[key.stringValue] = intValue
            } else if let doubleValue = try? propertiesContainer.decode(Double.self, forKey: key) {
                propsDict[key.stringValue] = doubleValue
            } else if let stringValue = try? propertiesContainer.decode(String.self, forKey: key) {
                propsDict[key.stringValue] = stringValue
            }
            // Only handle the basic types: string, boolean, numeric
        }

        properties = propsDict
    }
}

// Utility struct for dynamic coding keys
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

/// Gaze event data
public struct GazeEventData: Codable {
    /// Time recorded as a unix timestamp
    public let time: Double

    /// Position of the floor, directly below the HMD
    public let floorPosition: [Double]

    /// Gaze point in world space
    public let gazePoint: [Double]

    /// Position of the HMD in world space
    public let headPosition: [Double]

    /// Rotation (quaternion) of the HMD in world space
    public let headRotation: [Double]

    /// ID of a Dynamic Object that the participant is gazing at (if one exists).
    /// If set, this value is in local space on the Dynamic Object; otherwise, it is in world space.
    /// If missing, the participant is either looking at the sky or not looking at anything.
    public let objectId: String?

    private enum CodingKeys: String, CodingKey {
        case time
        case floorPosition = "f"
        case gazePoint = "g"
        case headPosition = "p"
        case headRotation = "r"
        case objectId = "o"
    }
}

extension GazeEventData {
    public func debugPrint() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let date = Date(timeIntervalSince1970: time)

        var output = """
        GazeEvent at \(dateFormatter.string(from: date)):
        \t‣ Floor: [\(formatVector(floorPosition))]
        \t‣ Gaze:  [\(formatVector(gazePoint))]
        \t‣ Head:  [\(formatVector(headPosition))]
        \t‣ Rot:   [\(formatVector(headRotation))]
        """

        if let objectId = objectId {
            output += "\n  Obj:   \(objectId)"
        }

        return output
    }

    private func formatVector(_ vector: [Double]) -> String {
        vector.map { String(format: "%.1f", $0) }.joined(separator: ", ")
    }
}
