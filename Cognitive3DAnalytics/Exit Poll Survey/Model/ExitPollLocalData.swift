//
//  LocalData.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-03-10.
//

import Foundation

// MARK: - Offline Storage Data Models

/// Structure for storing exit poll data locally
@available(*, deprecated, message: "The ExitPollSurvey now uses the DataCacheSystem.")
struct ExitPollLocalData: Codable {
    /// Timestamp when the data was saved
    let timestamp: TimeInterval

    /// The hook used to identify the exit poll
    let hook: String

    /// Scene ID associated with the exit poll
    let sceneId: String

    /// Position data for the exit poll
    let position: [Double]

    /// The question set ID
    let questionSetId: String

    /// The question set name (used for API endpoint)
    let questionSetName: String

    /// Version number for the question set
    let versionNumber: Int

    /// Version ID for the question set
    let versionId: Int

    /// Session ID at the time of storage
    let sessionId: String

    /// Participant ID (if available)
    let participantId: String

    /// User/device ID
    let userId: String

    /// Array of question data
    let questions: [QuestionData]

    /// Voice recordings data (base64 encoded)
    let voiceRecordings: [Int: String]

    // Standard initializer
    init(timestamp: TimeInterval, hook: String, sceneId: String, position: [Double],
         questionSetId: String, questionSetName: String, versionNumber: Int, versionId: Int,
         sessionId: String, participantId: String, userId: String,
         questions: [QuestionData], voiceRecordings: [Int: String]) {
        self.timestamp = timestamp
        self.hook = hook
        self.sceneId = sceneId
        self.position = position
        self.questionSetId = questionSetId
        self.questionSetName = questionSetName
        self.versionNumber = versionNumber
        self.versionId = versionId
        self.sessionId = sessionId
        self.participantId = participantId
        self.userId = userId
        self.questions = questions
        self.voiceRecordings = voiceRecordings
    }

    // Custom initializer for decoding that handles missing questionSetName
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode all required fields
        timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        hook = try container.decode(String.self, forKey: .hook)
        sceneId = try container.decode(String.self, forKey: .sceneId)
        position = try container.decode([Double].self, forKey: .position)
        questionSetId = try container.decode(String.self, forKey: .questionSetId)
        versionNumber = try container.decode(Int.self, forKey: .versionNumber)
        versionId = try container.decode(Int.self, forKey: .versionId)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        participantId = try container.decode(String.self, forKey: .participantId)
        userId = try container.decode(String.self, forKey: .userId)
        questions = try container.decode([QuestionData].self, forKey: .questions)
        voiceRecordings = try container.decode([Int: String].self, forKey: .voiceRecordings)

        // Try to decode questionSetName if it exists
        if let name = try? container.decodeIfPresent(String.self, forKey: .questionSetName) {
            questionSetName = name
        } else {
            // Extract name from ID as fallback
            if questionSetId.contains(":") {
                questionSetName = String(questionSetId.split(separator: ":").first ?? "")
            } else {
                questionSetName = questionSetId
            }
        }
    }
}

/// Structure for storing question data
struct QuestionData: Codable {
    /// Index of the question
    let index: Int

    /// Type of question
    let type: String

    /// Answer value
    let answer: Int
}

/// Structure for storing event data locally
struct EventLocalData: Codable {
    /// Timestamp when the data was saved
    let timestamp: TimeInterval

    /// Event name
    let eventName: String

    /// Hook associated with the event
    let hook: String

    /// Scene ID
    let sceneId: String

    /// Position data
    let position: [Double]

    /// Question set ID
    let questionSetId: String

    /// Participant ID (if available)
    let participantId: String

    /// User ID
    let userId: String

    /// Duration of the exit poll session
    let duration: TimeInterval

    /// Array of answer data
    let answers: [AnswerData]
}

/// Structure for storing answer data
struct AnswerData: Codable {
    /// Answer key (e.g., "Answer0")
    let key: String

    /// Answer value
    let value: Int
}

// MARK: - File Management Helpers


/// Generic helper to add a file to a tracking list
private func addToTrackingList(fileURL: URL, listName: String) throws {
    // Get or create the tracking list file URL
    let trackingListURL = try FileManager.default.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
    ).appendingPathComponent(listName)

    // Read existing list or create a new one
    var trackedFiles: [String] = []

    if FileManager.default.fileExists(atPath: trackingListURL.path) {
        let data = try Data(contentsOf: trackingListURL)
        trackedFiles = try JSONDecoder().decode([String].self, from: data)
    }

    // Add the new file to the list if it's not already there
    let filename = fileURL.lastPathComponent
    if !trackedFiles.contains(filename) {
        trackedFiles.append(filename)
    }

    // Save the updated list
    let encoder = JSONEncoder()
    let data = try encoder.encode(trackedFiles)
    try data.write(to: trackingListURL)
}
