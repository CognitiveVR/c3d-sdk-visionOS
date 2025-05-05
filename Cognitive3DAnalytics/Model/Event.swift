//
//  Event.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-11-26.
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// MARK: - Event data model
/// Custom event data model that gets uploaded to the Cognitive3D analytics back-end & viewed in the dashboard.
public struct Event: Codable {

    /// Unique identifier for the user
    let userId: String

    /// Time stamp for when the session started
    let timestamp: Double

    ///  Unique id for the session; it is a combination of the time stamp & user id
    ///  e.g.  "1581442899_6f89ecadc3a44ea3748f380552d608b1e911d074"
    let sessionId: String

    /// The part number gets incremented every time a post is made.
    /// Data is sent every 10 seconds or once the array of data is >128 items (these numbers are configurable)”
    let part: Int

    /// version style for the JSON data; e.g 1.0
    let formatVersion: String

    /// Additional event data
    let data: [EventData]

    private enum CodingKeys: String, CodingKey {
        case formatVersion = "formatversion"
        case sessionId = "sessionid"
        case userId = "userid"
        case data
        case part
        case timestamp
    }
}

/// Represents an individual event with it's optional associated data
struct EventData: Codable {
    /// Name of the event
    /// e.g. "c3d.sessionStart"
    let name: String

    /// Time when the event occurred
    let time: Double

    /// X, Y, Z co-ordinate associated with the event
    let point: [Double]

    // Additional optional data associated with the event
    let properties: [String: FreeformData]?

    /// Optional ID of a dynamic object associated with this event
    let dynamicObjectId: String?

    // Coding keys to match server expectations
    private enum CodingKeys: String, CodingKey {
        case name
        case time
        case point
        case properties
        case dynamicObjectId = "dynamicId"  // Server expects "dynamicId"
    }
}
