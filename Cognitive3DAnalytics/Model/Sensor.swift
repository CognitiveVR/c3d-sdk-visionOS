//
//  Sensor.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-11-27.
//

import Foundation

// MARK: - Sensor data model
/// Sensor data model
public struct Sensor: Codable {
    /// Unique identifier for the user
    let userId: String

    /// Time stamp for when the session started
    let timestamp: Double

    ///  Unique id for the session
    let sessionId: String

    /// The part number gets incremented every time a post is made.
    let part: Int

    /// version style for the JSON data
    let formatVersion: String

    /// Type of session
    let sessionType: String

    /// Additional sensor data
    let data: [SensorEventData]

    private enum CodingKeys: String, CodingKey {
        case formatVersion = "formatversion"
        case sessionId = "sessionid"
        case userId = "userid"
        case sessionType = "sessiontype"
        case data
        case part
        case timestamp
    }
}

/// Represents sensor data with associated readings
struct SensorEventData: Codable {
    /// Name of the sensor
    let name: String

    /// Array of timestamp and value pairs
    let data: [[Double]]
}
