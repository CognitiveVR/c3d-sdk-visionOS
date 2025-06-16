//
//  ExitPollAnswer.swift
//  Cognitive3DAnalytics
//
//  Created by Calder Archinuk on 2024-11-18.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//


public enum ExitPollAnswerType: String, Codable {
    case null
    case string
    case number
    case boolean
}


/// Data model for exit poll survey answers; there are three types of answers: string, number, and boolean.
public class ExitPollAnswer: Codable {
    var answerValueType: ExitPollAnswerType
    var stringValue: String
    var numberValue: Int
    var boolValue: Bool

    enum CodingKeys: String, CodingKey {
        case answerValueType
        case stringValue
        case numberValue
        case boolValue
    }

    /// Default initializer
    public init(answerValueType: ExitPollAnswerType = .null, stringValue: String = "", numberValue: Int = 0, boolValue: Bool = false) {
        self.answerValueType = answerValueType
        self.stringValue = stringValue
        self.numberValue = numberValue
        self.boolValue = boolValue
    }

    /// Convenience initializer for mapping from question answers
    public convenience init(type: String, value: Any) {
        let answerType = ExitPollAnswerType(rawValue: type) ?? .null

        switch answerType {
        case .string:
            self.init(answerValueType: answerType, stringValue: value as? String ?? "")
        case .number:
            self.init(answerValueType: answerType, numberValue: value as? Int ?? 0)
        case .boolean:
            self.init(answerValueType: answerType, boolValue: value as? Bool ?? false)
        default:
            self.init(answerValueType: .null)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(answerValueType, forKey: .answerValueType)
        try container.encode(stringValue, forKey: .stringValue)
        try container.encode(numberValue, forKey: .numberValue)
        try container.encode(boolValue, forKey: .boolValue)
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        answerValueType = try container.decode(ExitPollAnswerType.self, forKey: .answerValueType)
        stringValue = try container.decode(String.self, forKey: .stringValue)
        numberValue = try container.decode(Int.self, forKey: .numberValue)
        boolValue = try container.decode(Bool.self, forKey: .boolValue)
    }
}
