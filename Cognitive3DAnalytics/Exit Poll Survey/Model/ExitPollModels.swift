//
//  ExitPollModels.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// When there is no answer given for a question, use this value -32768.
public let noAnswerSet = -32768

/// Enum for the different types of questions.
public enum QuestionType: String, Codable {

    /// Boolean: true, false
    case boolean = "BOOLEAN"

    /// Happy, Sad
    case happySad = "HAPPYSAD"

    // Thumbs up, Thumbs down
    case thumbs = "THUMBS"

    /// Multiple choice
    case multiple = "MULTIPLE"

    /// Numeric scale using a range with a mininum & maximum value
    case scale = "SCALE"

    /// Voice : user records audio for their response to a question.
    case voice = "VOICE"
}

public struct ExitPollResponse: Codable {
    public let id: String
    public let projectId: Int
    public let name: String
    public let customerId: String
    public let status: String
    public let title: String
    public let questionSetVersion: Int
    public let questions: [Question]

    public init(
        id: String,
        projectId: Int,
        name: String,
        customerId: String,
        status: String,
        title: String,
        version: Int,
        questions: [Question]
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.customerId = customerId
        self.status = status
        self.title = title
        self.questionSetVersion = version
        self.questions = questions
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectId, name, customerId, status, title, questions
        case questionSetVersion = "version"
    }
}

/// The Question type is handling different types of questions, some question types have additional data.
public struct Question: Codable {
    public let type: QuestionType
    public let saveToSession: Bool
    public let propertyLabel: String?
    public let title: String

    ///  Property for multiple choice questions
    public let answers: [Answer]?

    /// Properties for scale questions
    public let minLabel: String?
    public let maxLabel: String?
    public let range: Range?

    /// Property for voice reply questions.
    public let maxResponseLength: Int?

    // Default to -32768 for skipped questions
    public var answer: Int

    public init(
        type: QuestionType,
        saveToSession: Bool,
        propertyLabel: String?,
        title: String,
        answers: [Answer]?,
        minLabel: String?,
        maxLabel: String?,
        range: Range?,
        maxResponseLength: Int?,
        answer: Int = noAnswerSet // Default for skipped state
    ) {
        self.type = type
        self.saveToSession = saveToSession
        self.propertyLabel = propertyLabel
        self.title = title
        self.answers = answers
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.range = range
        self.answer = answer
        self.maxResponseLength = maxResponseLength
    }

    // Custom decoding to handle missing `answer`
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(QuestionType.self, forKey: .type)
        self.saveToSession = try container.decode(Bool.self, forKey: .saveToSession)
        self.propertyLabel = try container.decodeIfPresent(String.self, forKey: .propertyLabel)
        self.title = try container.decode(String.self, forKey: .title)
        self.answers = try container.decodeIfPresent([Answer].self, forKey: .answers)
        self.minLabel = try container.decodeIfPresent(String.self, forKey: .minLabel)
        self.maxLabel = try container.decodeIfPresent(String.self, forKey: .maxLabel)
        self.range = try container.decodeIfPresent(Range.self, forKey: .range)
        self.maxResponseLength = try container.decodeIfPresent(Int.self, forKey: .maxResponseLength)
        self.answer = try container.decodeIfPresent(Int.self, forKey: .answer) ?? -32768
    }

    // Encoding is standard
    private enum CodingKeys: String, CodingKey {
        case type, saveToSession, propertyLabel, title, answers, minLabel, maxLabel, range, answer, maxResponseLength
    }
}
public struct Answer: Codable {
    public let icon: String?
    public let answer: String

    public init(icon: String?, answer: String) {
        self.icon = icon
        self.answer = answer
    }
}

public struct Range: Codable {
    public let start: Int
    public let end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

struct CodableWrapper: Codable {
    let value: AnyCodable

    init<T: Codable>(_ value: T) {
        self.value = AnyCodable(value)
    }
}

public struct AnyCodable: Codable {
    public let value: Any

    public init<T>(_ value: T?) {
        self.value = value ?? ()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = ()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let array = value as? [Any] {
            let encodableArray = array.map { AnyCodable($0) }
            try container.encode(encodableArray)
        } else if let dictionary = value as? [String: Any] {
            let encodableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(encodableDictionary)
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

extension Question {
    public var answerString: String? {
        get {
            if let answers = self.answers, answer >= 0, answer < answers.count {
                return answers[answer].answer // Maps index to string
            }
            return nil
        }
        set {
            if let newValue = newValue,
               let index = answers?.firstIndex(where: { $0.answer == newValue }) {
                self.answer = index // Maps string back to index
            } else {
                self.answer = -1 // No selection
            }
        }
    }
}
