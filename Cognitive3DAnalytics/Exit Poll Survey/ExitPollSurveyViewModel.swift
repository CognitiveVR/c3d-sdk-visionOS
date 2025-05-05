//
//  ExitPollSurveyViewModel.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-01-02.
//

import Combine
import Foundation
import SwiftUI

/// Represents errors that can occur when fetching or managing exit poll surveys.
public enum ExitPollSurveyError: Error {
    /// A network error occurred, with an optional message providing details.
    case networkError(String)

    /// The response from the server was invalid or unexpected.
    case invalidResponse

    /// No questions were retrieved from the survey.
    case noQuestionsRetrieved

    /// This property returns a descriptive message based on the type of error,
    /// making it suitable for display in UI alerts or logs.
    public var localizedDescription: String {
        switch self {
        case .networkError(let message):
            // Use the provided message if available; otherwise, provide a default message
            return message.isEmpty ? "A network error occurred." : message
        case .invalidResponse:
            // Error description for invalid server responses
            return "The server response was invalid. Please try again later."
        case .noQuestionsRetrieved:
            // Error description for cases where no survey questions are available
            return "No questions were retrieved for the survey. Please contact support if this persists."
        }
    }
}

/// View model for managing the state and data of the exit poll survey.
public class ExitPollSurveyViewModel: ObservableObject {
    /// Indicates whether the survey is currently being loaded.
    @Published private(set) var isLoading = false

    /// The error message to display when an error occurs.
    @Published public var errorMessage: String?

    /// The list of survey questions to be displayed to the user.
    @Published public var surveyQuestions: [Question] = []

    /// Dictionary to store voice recordings (base64 encoded audio data)
    private var microphoneResponsesStorage: [Int: String] = [:]

    /// Provides access to voice recordings
    public var microphoneResponses: [Int: String] {
        get { return microphoneResponsesStorage }
        set { microphoneResponsesStorage = newValue }
    }

    private let exitPollSurvey: ExitPollSurvey

    /// The hook name for the question set.
    @Published public private(set) var hook: String = ""

    /// Title for the question set.
    public var title: String = ""

    /// String identifier for the question set.
    public var questionSetName: String = ""

    /// Id for the question set.
    public var questionSetId: String = ""

    /// The question set version is required when posting the survey answers.
    /// The current question set version should be obtained when fetching the survey questions.
    public var questionSetVersion: Int = 1

    public var versionId: Int = 0

    private let core: Cognitive3DAnalyticsCore

    public var time: Date?

    private let isPositionIncluded = true

    /// Initializes the view model with the shared analytics core.
    public init() {
        core = Cognitive3DAnalyticsCore.shared
        self.exitPollSurvey = ExitPollSurvey(core: core)
        if let config = core.config, let scene = config.allSceneData.first {
            versionId = scene.versionId
        }
    }

    /// Fetches the exit poll survey using the provided hook value.
    /// - Parameter hook: A unique identifier for the survey to fetch.
    /// - Returns: A `Result` containing `Void` on success or an error on failure.
    public func fetchSurvey(hook: String) async -> Result<Void, ExitPollSurveyError> {
#if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            useMockData()
            return .success(())
        }
#endif

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        let result = await exitPollSurvey.fetchExitPollQuestions(hook: hook)

        return await MainActor.run { [weak self] in
            guard let self = self else {
                return .failure(.networkError("ViewModel deallocated."))
            }

            self.isLoading = false
            switch result {
            case .success(let response):
                if response.questions.isEmpty {
                    self.errorMessage = "No questions were retrieved. Please contact support."
                    return .failure(.noQuestionsRetrieved)
                } else {
                    self.surveyQuestions = response.questions
                    self.questionSetVersion = response.questionSetVersion
                    self.questionSetName = response.name
                    self.questionSetId = response.id
                    self.title = response.title
                    self.hook = hook
                    self.time = Date()
                    return .success(())
                }
            case .failure(let apiError):
                self.errorMessage = apiError.description
                core.logger?.error("error fetching exit poll survey: \(apiError.description)")
                return .failure(.networkError(apiError.description))
            }
        }
    }

    /// Handles error responses by displaying appropriate error messages.
    /// - Parameter error: The error encountered during the survey fetch.
    private func handleErrorResponse(_ error: any Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .notFound:
                self.errorMessage = "Survey not found. Please verify the hook name."
            case .forbidden:
                self.errorMessage = "You are not authorized to access this survey."
            default:
                self.errorMessage = "An error occurred while fetching the survey: \(error.localizedDescription)"
            }
        } else {
            self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    /// Sends all collected answers to the server.
    /// - Parameters:
    ///   - hook: The unique identifier for the survey.
    ///   - sceneId: The scene ID associated with the survey.
    ///   - position: An optional array representing the user's position.
    ///
    internal func sendAllAnswers(hook: String, sceneId: String, position: [Double]? = nil) async -> Result<Void, Error> {
        do {
            try await exitPollSurvey.sendAllAnswers(
                using: self, hook: hook, sceneId: sceneId, questionSetVersion: questionSetVersion, position: position)

            await MainActor.run {
                errorMessage = nil  // Clear previous errors on success
                core.logger?.verbose("Survey answers successfully sent.")
            }

            return .success(())
        } catch {
            await MainActor.run {
                // Set error message based on the error type and context
                if let apiError = error as? APIError {
                    // Check if it's a server error with voice recordings
                    if case .serverError(502) = apiError, !microphoneResponsesStorage.isEmpty {
                        errorMessage = "Unable to submit survey with audio recordings. Please try with shorter recordings."
                    } else if case .serverError(413) = apiError, !microphoneResponsesStorage.isEmpty {
                        errorMessage = "Audio recordings are too large to submit. Please try shorter recordings."
                    } else {
                        // Use the default error description for other API errors
                        errorMessage = apiError.description
                    }
                } else {
                    // For other error types, use the default description
                    errorMessage = error.localizedDescription
                }

                core.logger?.error("Error while sending survey answers: \(error.localizedDescription)")
            }

            return .failure(error)
        }
    }

    /// Send the survey answers to the server or store locally if network errors occur using the local data cache.
    public func sendSurveyAnswers() async -> Result<Void, Error> {
        core.logger?.info("Starting to send survey answers")

        let sessionManager = ARSessionManager.shared

        // Get position data
        let position: [Double]
        if sessionManager.isTrackingActive {
            position = sessionManager.getPosition() ?? [0.0, 0.0, 0.0]
        } else {
            position = [0.0, 0.0, 0.0]
        }
        let sceneId = core.getCurrentSceneId()

        // Attempt to send data immediately
        core.logger?.info("Attempting to send survey answers")

        // Handle sendAllAnswers result
        let sendResult: Result<Void, Error> =
            isPositionIncluded
            ? await sendAllAnswers(hook: hook, sceneId: sceneId, position: position)
            : await sendAllAnswers(hook: hook, sceneId: sceneId)

        switch sendResult {
        case .failure(let error):
            core.logger?.error("Failed to send survey answers: \(error.localizedDescription)")

            // Check if it's a network error and fall back to caching
            if core.isNetworkError(error) {
                core.logger?.info("Network error detected, falling back to local storage")
                return await cacheExitPollResponsesToSendLater(sceneId: sceneId, position: position)
            }
            return .failure(error)

        case .success:
            // Handle recordSurveyEvent result
            let recordResult = await recordSurveyEvent(hook: hook, sceneId: sceneId, position: position)

            switch recordResult {
            case .failure(let error):
                core.logger?.error("Failed to record survey event: \(error.localizedDescription)")

                // Also check for network errors here and cache if needed
                if core.isNetworkError(error) {
                    core.logger?.info("Network error detected in event recording, falling back to local storage")
                    return await cacheExitPollResponsesToSendLater(sceneId: sceneId, position: position)
                }

                return .failure(error)
            case .success:
                core.logger?.info("Survey answers and event submitted successfully")
                return .success(())
            }
        }
    }

    /// Save the exit poll survey response to the local data cache
    #if DEBUG
    public func saveSurveyAnswers() async -> Result<Void, Error> {
        let sessionManager = ARSessionManager.shared

        // Get position data
        let position: [Double]
        if sessionManager.isTrackingActive {
            position = sessionManager.getPosition() ?? [0.0, 0.0, 0.0]
        } else {
            position = [0.0, 0.0, 0.0]
        }
        let sceneId = core.getCurrentSceneId()

        // Call our storeLocally method which now uses DataCacheSystem
        return await cacheExitPollResponsesToSendLater(sceneId: sceneId, position: position)
    }
    #endif

    // MARK: -
    // Helper function to verify network connection
    private func verifyNetworkConnection() async -> Bool {
        // First, check if NetworkReachabilityMonitor still reports connection
        if !NetworkReachabilityMonitor.shared.isConnected {
            core.logger?.verbose("Network monitor reports device is disconnected")
            return false
        }

        // Try to fetch the survey again as a connectivity test
        // We don't need to use the response, just check if the network request succeeds
        let result = await exitPollSurvey.fetchExitPollQuestions(hook: hook)

        switch result {
        case .success(_):
            core.logger?.verbose("Network verification successful - survey fetch succeeded")
            return true
        case .failure(let error):
            // If we get forbidden or not found, the network is actually working
            // These are server responses, which means we have connectivity
            if case .forbidden = error, case .notFound = error {
                core.logger?.verbose("Network verification successful - received server response")
                return true
            }

            core.logger?.verbose("Network verification failed: \(error.description)")
            return false
        }
    }


    // MARK: -
    /// Updates the answer for a specific question.
    /// - Parameters:
    ///   - index: The index of the question to update.
    ///   - value: The value of the user's answer.
    func updateAnswer(for index: Int, with value: Int) {
        guard index < surveyQuestions.count else { return }
        surveyQuestions[index].answer = value
    }

    /// Updates a question with a microphone recording answer (base64 encoded string)
    /// - Parameters:
    ///   - index: The index of the question to update
    ///   - base64Audio: The base64 encoded audio data
    func updateMicrophoneAnswer(for index: Int, with base64Audio: String) {
        guard index < surveyQuestions.count else { return }

        // For voice recordings, set answer to 0 as in the C# implementation
        surveyQuestions[index].answer = 0

        // Store the base64 audio data
        microphoneResponsesStorage[index] = base64Audio
    }

    /// Skips the question at the specified index by setting its answer to `-32768`.
    /// - Parameter index: The index of the question to skip.
    public func skipQuestion(at index: Int) {
        guard index < surveyQuestions.count else { return }
        surveyQuestions[index].answer = noAnswerSet
    }

    // MARK: -
    /// Loads mock data for use in SwiftUI previews.
    private func useMockData() {
        title = "Mock Survey"
        surveyQuestions = [
            Question(
                type: .boolean, saveToSession: false, propertyLabel: nil, title: "Do you like Swift?", answers: nil,
                minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .happySad, saveToSession: true, propertyLabel: nil, title: "How do you feel about this app?",
                answers: nil, minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .thumbs, saveToSession: false, propertyLabel: nil, title: "Would you recommend us?", answers: nil,
                minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .multiple, saveToSession: true, propertyLabel: nil, title: "What feature do you use most?",
                answers: [
                    Answer(icon: nil, answer: "Feature A"),
                    Answer(icon: nil, answer: "Feature B"),
                    Answer(icon: nil, answer: "Feature C"),
                ], minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .multiple, saveToSession: true, propertyLabel: nil, title: "2 chocies",
                answers: [
                    Answer(icon: nil, answer: "Choice A"),
                    Answer(icon: nil, answer: "Choice B"),
                ], minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .multiple, saveToSession: true, propertyLabel: nil, title: "4 chocies",
                answers: [
                    Answer(icon: nil, answer: "Choice 1"),
                    Answer(icon: nil, answer: "Choice 2"),
                    Answer(icon: nil, answer: "Choice 3"),
                    Answer(icon: nil, answer: "Choice 4"),
                ], minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
            Question(
                type: .scale, saveToSession: true, propertyLabel: nil, title: "Rate your experience", answers: nil,
                minLabel: "Poor", maxLabel: "Excellent", range: Range(start: 0, end: 10), maxResponseLength: nil),
            Question(
                type: .scale, saveToSession: true, propertyLabel: nil, title: "Pick a value from 1 to 5", answers: nil,
                minLabel: "1", maxLabel: "5", range: Range(start: 1, end: 5), maxResponseLength: nil),
            Question(
                type: .voice, saveToSession: true, propertyLabel: nil, title: "Tell us about your experience", answers: nil,
                minLabel: nil, maxLabel: nil, range: nil, maxResponseLength: nil),
        ]
    }

    // MARK: -
    /// Prepares the JSON response for collected answers, including any voice recordings.
    /// - Parameters:
    ///   - hook: The unique identifier for the survey hook.
    ///   - sceneId: The ID of the scene associated with the survey.
    ///   - questionSetVersion: The version of the question set.
    ///   - position: An optional array representing the user's position.
    /// - Returns: A dictionary representation of the full response.
    func prepareJSONResponse(hook: String, sceneId: String, questionSetVersion: Int, position: [Double]? = nil)
    -> [String: Any]
    {
        let answers = surveyQuestions.enumerated().map { (index, question) -> [String: Any] in
            // Check if we have a voice recording for this index
            if question.type == .voice, let base64Audio = microphoneResponsesStorage[index] {
                return ["type": "VOICE", "value": base64Audio]
            }

            // Standard answer handling for other question types
            let type: String
            let value: Any

            switch question.type {
            case .boolean:
                type = "BOOLEAN"
                value = question.answer
            case .happySad:
                type = "HAPPYSAD"
                value = question.answer
            case .thumbs:
                type = "THUMBS"
                value = question.answer
            case .multiple, .scale:
                type = question.type.rawValue.uppercased()
                value = question.answer
            case .voice:
                // Voice question but no recording available
                type = "VOICE"
                value = 0  // Default value when no recording is available
            @unknown default:
                type = "UNKNOWN"
                value = noAnswerSet
            }

            return ["type": type, "value": value]
        }

        // Create the response dictionary
        var response: [String: Any] = [
            "userId": Cognitive3DAnalyticsCore.shared.getUserId(),
            "questionSetId": questionSetId,
            "sessionId": Cognitive3DAnalyticsCore.shared.getSessionId(),
            "hook": hook,
            "sceneId": sceneId,
            "versionNumber": questionSetVersion,
            "versionId": versionId,
            "answers": answers,
        ]

        // Include `position` if it's provided
        if let position = position {
            response["position"] = position
        }

        return response
    }

    /// Generates a pretty-printed JSON representation of all collected answers.
    /// - Parameters:
    ///   - hook: The unique identifier for the survey hook.
    ///   - sceneId: The ID of the scene associated with the survey.
    ///   - questionSetVersion: The version of the question set.
    /// - Returns: A pretty-printed JSON string.
    public func generatePrettyJSON(
        hook: String,
        sceneId: String,
        questionSetVersion: Int
    ) -> String {
        let response = prepareJSONResponse(
            hook: hook,
            sceneId: sceneId,
            questionSetVersion: questionSetVersion
        )

        // Generate pretty-printed JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: response, options: .prettyPrinted)
            if let prettyString = String(data: jsonData, encoding: .utf8) {
#if DEBUG
                print(prettyString)
#endif
                return prettyString
            } else {
                return "Failed to generate JSON string."
            }
        } catch {
            return "Error generating JSON: \(error.localizedDescription)"
        }
    }

    /// Records a custom event for the exit poll survey.
    /// - Parameters:
    ///   - hook: The unique identifier for the survey hook.
    ///   - sceneId: The ID of the scene associated with the survey.
    ///   - questionSetVersion: The version of the question set.
    ///   - position: Optional 3D position of the event.
    ///   - duration: Duration of the survey session.
    ///   - immediate: Whether to send immediately or batch.
    /// - Returns: Success status.
    @discardableResult
    internal func recordSurveyEvent(hook: String, sceneId: String, position: [Double], immediate: Bool = true) async
    -> Result<Void, Error>
    {
        // Create event properties
        let properties = createEventProperties(hook: hook, sceneId: sceneId)

        // Send to server
        return await sendEvent(name: "cvr.exitpoll", position: position, properties: properties, immediate: immediate)
    }

    // MARK: - Helper Methods
    /// Creates the event properties dictionary
    private func createEventProperties(hook: String, sceneId: String) -> [String: Any] {
        // Calculate duration
        let duration: TimeInterval = time != nil ? Date().timeIntervalSince(time!) : 0

        // Prepare answers as properties
        var properties: [String: Any] = [:]
        for (index, question) in surveyQuestions.enumerated() {
            let key = "Answer\(index)"
            properties[key] = question.answer
        }

        // Add additional properties
        properties["userId"] = core.getUserId()
        properties["duration"] = duration
        properties["questionSetId"] = questionSetId
        properties["hook"] = hook
        properties["sceneId"] = sceneId

        let participantId = core.getParticipantId()
        if !participantId.isEmpty {
            properties["participantId"] = participantId
        }

        return properties
    }

    /// Sends the event with the specified properties
    private func sendEvent(name: String, position: [Double], properties: [String: Any], immediate: Bool) async -> Result<Void, Error> {
        let customEventRecorder = Cognitive3DAnalyticsCore.shared.customEventRecorder
        let currentSceneId = core.getCurrentSceneId()

        guard let eventRecorder = customEventRecorder else {
            core.logger?.error("Cannot record custom event: No event recorder available")
            return .failure(
                NSError(
                    domain: "RecordSurveyEventError", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "No event recorder available"]))
        }

        guard !currentSceneId.isEmpty else {
            core.logger?.error("Cannot record event: No scene set")
            return .failure(
                NSError(
                    domain: "RecordSurveyEventError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No scene set"]))
        }

        // Record the event
        let success = eventRecorder.recordEvent(
            name: name,
            position: position,
            properties: properties,
            immediate: immediate)

        if success {
            return .success(())
        } else {
            return .failure(
                NSError(
                    domain: "RecordSurveyEventError", code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to record event"]))
        }
    }

    // MARK: -
    /// Save the participant's responses to the local data cache; there are 2 parts to this: the responses and the and an event to get cached.
    private func cacheExitPollResponsesToSendLater(sceneId: String, position: [Double]) async -> Result<Void, Error> {
        do {
            // Prepare the JSON response for the exit poll answers
            let responseJSON = prepareJSONResponse(
                hook: hook,
                sceneId: sceneId,
                questionSetVersion: questionSetVersion,
                position: position
            )
            let responseData = try JSONSerialization.data(withJSONObject: responseJSON)

            // Prepare event properties
            let eventProperties = createEventProperties(hook: hook, sceneId: sceneId)

            // Call the updated exitPollSurvey's method with prepared data
            return await exitPollSurvey.cacheExitPollResponsesToSendLater(
                responseData: responseData,
                questionSetName: questionSetName,
                questionSetVersion: questionSetVersion,
                eventProperties: eventProperties
            )
        } catch {
            core.logger?.error("Failed to serialize data for caching: \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
