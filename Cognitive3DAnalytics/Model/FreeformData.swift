//
//  FreeformData.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2024-11-28.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//
/// Freeform data enum adopting the Codable protocol to represent all possible JSON value types.
/// Events can have additional data that does not adhere to a single definition.  It can be a dictionary or array of dictionaries with differing key value pairs & so on.
///
/// Example 1
///
/// ```JSON
/// "data" : [
///  {
///   "name" : "c3d.SceneChange",
///   "time" : 1581442904.23179,
///   "point" : [
///     -4.65433,
///     1.6369,
///     -4.7159
///   ],
///   "properties" : {
///     "Duration" : 2.007557,
///     "Scene Name" : "factory scene",
///     "Scene Id" : "cc508973-eaff-4055-8644-233f5d8c7bba"
///   }
///  }
/// ]
/// ```
///
/// Example 2
///
/// ```JSON
/// "data" : [
///  {
///    "partNumberAndIdxKey" : 700000,
///    "name" : "Time To Fun",
///    "time" : 1732210233.696,
///    "point" : [
///      0,
///      0.009990000165998936,
///      -1.7400000095367432
///    ],
///    "properties" : {
///     "duration" : 27.41107940673828
///    }
///   }
///  ]
/// ```
///
enum FreeformData: Codable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case array([FreeformData])
    case object([String: FreeformData])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode([FreeformData].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: FreeformData].self) {
            self = .object(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid JSON value"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - FreeformData Extensions

extension FreeformData {
    /// Create a FreeformData from any valid JSON-compatible value
    static func from(_ value: Any) throws -> FreeformData {
        switch value {
        case let string as String:
            return .string(string)
        case let number as Double:
            return .number(number)
        case let number as Int:
            return .integer(number)
        case let bool as Bool:
            return .boolean(bool)
        case let array as [Any]:
            return try .array(array.map { try from($0) })
        case let dict as [String: Any]:
            return try .object(
                Dictionary(
                    uniqueKeysWithValues:
                        dict.map { key, value in
                            (key, try from(value))
                        }
                ))
        case Optional<Any>.none:
            return .null
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Value is not JSON compatible"
                ))
        }
    }

    /// Convert Dictionary to FreeformData properties
    static func fromDictionary(_ dictionary: [String: Any]) throws -> [String: FreeformData] {
        try dictionary.mapValues { try from($0) }
    }

    /// Extract the underlying value
    var value: Any? {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .integer(let value): return value
        case .boolean(let value): return value
        case .array(let value): return value.map { $0.value }
        case .object(let value): return value.mapValues { $0.value }
        case .null: return nil
        }
    }
}

// MARK: - EventData Extension

extension EventData {
    /// Convenience initializer for EventData with dictionary
    init(
        name: String,
        time: Double,
        point: [Double],
        propertyDict: [String: Any]?,
        dynamicObjectId: String? = nil
    ) throws {
        self.name = name
        self.time = time
        self.point = point
        self.properties = try propertyDict.map { try FreeformData.fromDictionary($0) }
        self.dynamicObjectId = dynamicObjectId
    }
}
