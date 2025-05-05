//
//  Dynamic.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-11-27.
//

// MARK: - Dynamic data model
/// Dynamic session  data model
// They represent the transform (position, rotation, scale) of objects in the environment. For example, a car might be a dynamic object, or a poster
struct DynamicSession: Codable {
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

    /// A collection of meshes (3D objects)  in a scene
    let manifest: [String: ManifestEntry]

    /// the event data
    let data: [DynamicEventData]

    private enum CodingKeys: String, CodingKey {
        case formatVersion = "formatversion"
        case sessionId = "sessionid"
        case userId = "userid"
        case data
        case part
        case timestamp
        case manifest
    }
}

/// Manifest - list of meshes in the app/game scene
struct Manifest: Codable {
    var manifest: [String: ManifestEntry]
}

/// The manifest entry is used to register dynamic objects in the scene for the current analytics session.
struct ManifestEntry: Codable, Equatable {
    /// Name of the actor in an scene
    let name: String

    /// Name of the file mesh.
    let mesh: String

    /// The type of file for the mesh; e.g. GLTF
    let fileType: String

    enum CodingKeys: String, CodingKey {
        case name
        case mesh
        case fileType
    }
}

/// This struct is used to record transform snapshots for dynamic objects during an analytics session.
struct DynamicEventData: Codable {
    /// id for the object
    let id: String

    /// The time of the event.
    let time: Double

    /// position [x, y, z]
    let p: [Double]

    /// rotation quaternion [x, y, z, w]
    let r: [Double]

    /// scale [x, y, z] - optional, only included when scale has changed
    let s: [Double]?

    /// additional properties like whether the object is enabled or not.
    let properties: [[String: AnyCodable]]?

    /// button states for controllers
    let buttons: Buttons?

    enum CodingKeys: String, CodingKey {
        case id
        case time
        case p
        case r
        case s
        case properties
        case buttons
    }
}

// TODO: controllers with buttons are not currently part of C3D SDK development for visionOS.
struct Buttons: Codable {
    private let state: InputObjectState
    private let keyName: String

    subscript(key: String) -> InputObjectState? {
        return key == keyName ? state : nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        guard let key = container.allKeys.first else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "No keys found in Buttons object"
                )
            )
        }

        keyName = key.stringValue
        state = try container.decode(InputObjectState.self, forKey: StringCodingKey(stringValue: keyName)!)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        try container.encode(state, forKey: StringCodingKey(stringValue: keyName)!)
    }
}

struct InputObjectState: Codable {
    let buttonPercent: Double
    let x: Double
    let y: Double
}

struct StringCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
