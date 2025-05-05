//
//  ExitPollFullResponse.swift
//  Cognitive3DAnalytics
//

import Foundation

public struct ExitPollFullResponse: Codable {
    public let userId: String
    public let questionSetId: String
    public let sessionId: String
    public let hook: String
    /// id for thes scene to associate the survey answers with .
    public let sceneId: String
    public let versionNumber: Int
    public let versionId: Int
    public let answers: [ExitPollAnswer]

    /// Initializes an `ExitPollFullResponse`.
    public init(
        userId: String,
        questionSetId: String,
        sessionId: String,
        hook: String,
        sceneId: String,
        versionNumber: Int,
        versionId: Int,
        answers: [ExitPollAnswer]
    ) {
        self.userId = userId
        self.questionSetId = questionSetId
        self.sessionId = sessionId
        self.hook = hook
        self.sceneId = sceneId
        self.versionNumber = versionNumber
        self.versionId = versionId
        self.answers = answers
    }

    /// Generates a JSON dictionary for posting to the server.
    public func toJSON() -> [String: Any] {
        let answersArray = answers.map { answer -> [String: Any] in
            var value: Any

            if !answer.stringValue.isEmpty {
                value = answer.stringValue // String
            } else if answer.numberValue != 0 {
                value = answer.numberValue // Int
            } else {
                value = answer.boolValue // Bool
            }

            return [
                "type": answer.answerValueType.rawValue,
                "value": value
            ]
        }

        return [
            "userId": userId,
            "questionSetId": questionSetId,
            "sessionId": sessionId,
            "hook": hook,
            "sceneId": sceneId,
            "versionNumber": versionNumber,
            "versionId": versionId,
            "answers": answersArray
        ]
    }

    /// Generates a pretty-printed JSON string for debugging or display.
    public func toPrettyPrintedJSON() -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: toJSON(), options: .prettyPrinted)
            if let prettyString = String(data: jsonData, encoding: .utf8) {
                return prettyString
            } else {
                return "Failed to encode JSON string."
            }
        } catch {
            return "Error generating pretty-printed JSON: \(error.localizedDescription)"
        }
    }
}
