//
//  ExitPollSurvey.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// The `ExitPollSurvey` class is used to fetch question sets using hooks and post the user's answers to the C3D back end.
/// This class works with the `ExitPollSurveyViewModel`.
public class ExitPollSurvey {
    internal var core: Cognitive3DAnalyticsCore
    internal let logger: CognitiveLog
    internal let networkClient: NetworkAPIClient

    /// Initializes the `ExitPollSurvey` with the analytics core and API key.
    /// - Parameter core: Configured instance of `Cognitive3DAnalyticsCore`.
    public init(core: Cognitive3DAnalyticsCore) {
        self.core = core
        logger = CognitiveLog(category: "ExitPollSurvey")

        // Check if this is a testing context
        let isTesting = NSClassFromString("XCTestCase") != nil

        // Get API key from core configuration
        let apiKey = core.config?.applicationKey ?? ""

        // Only fatal error in non-test environment when API key is missing
        if apiKey.isEmpty && !isTesting {
            fatalError("API Key is required to initialize ExitPollSurvey.")
        }

        // Initialize with empty key if needed for tests
        networkClient = NetworkAPIClient(apiKey: apiKey, cog: core)

        // Inherit log level from core
        if let coreLogger = core.getLog() {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            logger.isDebugVerbose = coreLogger.isDebugVerbose
        }
    }

    // MARK: -
    /// Fetches the exit poll survey using the provided hook value.
    /// - Parameter hook: A unique identifier for the survey to fetch.
    /// - Returns: A result containing an array of questions or an error.
    public func fetchExitPollQuestions(hook: String) async -> Result<ExitPollResponse, APIError> {
        let endpoint = "questionSetHooks/\(hook)/questionSet"

        do {
            let response: ExitPollResponse = try await networkClient.makeRequest(
                endpoint: endpoint,
                sceneId: "",
                version: "",
                method: .get,
                body: nil as String?
            )

            logger.info("Successfully fetched \(response.questions.count) questions for hook \(hook).")
            return .success(response)
        } catch let error as APIError {
            logger.error("API error: \(error.description)")
            return .failure(error)
        } catch {
            logger.error("Unexpected error: \(error.localizedDescription)")
            return .failure(.networkError(error))
        }
    }

    // MARK: -
    func sendAllAnswers(using viewModel: ExitPollSurveyViewModel, hook: String, sceneId: String, questionSetVersion: Int, position: [Double]?) async throws {
        logger.info("Preparing to send all collected answers.")

        let fullResponse = viewModel.prepareJSONResponse(hook: hook, sceneId: sceneId, questionSetVersion: questionSetVersion, position: position)
        let endPoint = "questionSets/\(viewModel.questionSetName)/\(questionSetVersion)/responses"

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: fullResponse, options: [])

            let _: ExitPollResponse? = try await networkClient.makeRequest(
                endpoint: endPoint,
                sceneId: "",
                version: "",
                method: .post,
                rawBody: jsonData
            )

            logger.info("Survey answers submitted successfully.")
        } catch {
            logger.error("Error submitting survey answers: \(error)")
            throw error
        }
    }

    // MARK: -

    /// Save the resposnes to the local data cache
    public func cacheExitPollResponsesToSendLater(responseData: Data, questionSetName: String, questionSetVersion: Int, eventProperties: [String: Any]) async -> Result<Void, Error> {
        let responsesResult = await cacheExitPollResponses(responseData: responseData, questionSetName: questionSetName, questionSetVersion: questionSetVersion)
        switch responsesResult {
        case .success:
            let eventResult = await cacheExitPollEvent(eventProperties: eventProperties)
            switch eventResult {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    private func cacheExitPollResponses(responseData: Data, questionSetName: String, questionSetVersion: Int) async -> Result<Void, Error> {
        // Validate the question set name
        guard !questionSetName.isEmpty else {
            logger.error("Failed to create URL for exit poll answers: empty question set name")
            return .failure(NSError(domain: "ExitPollError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL - empty question set name"]))
        }

        // Create the URL for the API endpoint using NetworkEnvironment
        guard let url = NetworkEnvironment.current.constructExitPollURL(
            questionSetName: questionSetName,
            version: questionSetVersion
        ) else {
            logger.error("Failed to create URL for exit poll answers")
            return .failure(NSError(domain: "ExitPollError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
        }

        // Cache the data in the DataCacheSystem
        await core.dataCacheSystem?.cacheRequest(url: url, body: responseData)

        logger.info("Cached exit poll responses")
        return .success(())
    }

    private func cacheExitPollEvent(eventProperties: [String: Any]) async -> Result<Void, Error> {
        do {
            // Create the EventData structure
            let exitPollEventData = EventData(
                name: "cvr.exitpoll",
                time: core.getTimestamp(),
                point: core.defaultPos,
                properties: eventProperties.mapValues { self.convertToFreeformData($0) },
                dynamicObjectId: nil
            )

            // Create the complete Event structure
            let event = Event(
                userId: core.getUserId(),
                timestamp: core.getSessionTimestamp(),
                sessionId: core.getSessionId(),
                part: 1, // Assuming this is the first part for cached events
                formatVersion: analyticsFormatVersion1,
                data: [exitPollEventData]
            )

            // Convert the properly structured event to JSON data
            let properlyFormattedEventData = try JSONEncoder().encode(event)

            // Construct the URL string using the scene ID and version number
            let sceneId = core.getCurrentSceneId()
            let version = core.getCurrentSceneVersionNumber()
            let eventsEndpoint = "\(NetworkEnvironment.current.baseURL)/events/\(sceneId)?version=\(version)"

            guard let url = URL(string: eventsEndpoint) else {
                logger.error("Failed to create URL for exit poll event")
                return .failure(NSError(domain: "ExitPollError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid event URL"]))
            }

            // Cache the properly formatted event data
            await core.dataCacheSystem?.cacheRequest(url: url, body: properlyFormattedEventData)

            logger.info("Cached exit poll event")
            return .success(())
        } catch {
            logger.error("Failed to process event data: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // Helper method to convert values to FreeformData (copied from EventRecorder)
    private func convertToFreeformData(_ value: Any) -> FreeformData {
        switch value {
        case let stringValue as String: return .string(stringValue)
        case let numberValue as Double: return .number(numberValue)
        case let boolValue as Bool: return .boolean(boolValue)
        default: return .string(String(describing: value))
        }
    }
}
