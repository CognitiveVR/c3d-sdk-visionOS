//
//  ExitPollSurveyTests.swift
//  Cognitive3DAnalytics-coreTests
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Testing
import Foundation
@testable import Cognitive3DAnalytics

@Suite("Exit Poll Survey Tests")
struct ExitPollSurveyTests {
    @Test
    func cachingExitPollResponses() async throws {
        // Setup test environment
        let (mockCore, exitPollSurvey, _) = createTestEnvironment()

        // Create test data
        let responseData = createTestResponseData()
        let questionSetName = "test_question_set"
        let questionSetVersion = 1
        let eventProperties = createTestEventProperties()

        // Call the method with the expected parameters
        let result = await exitPollSurvey.cacheExitPollResponsesToSendLater(
            responseData: responseData,
            questionSetName: questionSetName,
            questionSetVersion: questionSetVersion,
            eventProperties: eventProperties
        )

        // Verify result
        switch result {
        case .success:
            // Success - check if data was cached
            if let cache = await mockCore.dataCacheSystem?.cache {
                let hasContent = cache.hasContent()
                #expect(hasContent)
            } else {
                throw TestFailure("Cache should be available")
            }
        case .failure(let error):
            throw TestFailure("Caching operation failed with error: \(error.localizedDescription)")
        }
    }

    @Test
    func cachingExitPollResponsesWithEmptyQuestionSetName() async throws {
        // Setup test environment
        let (_, exitPollSurvey, _) = createTestEnvironment()

        // Create test data with empty question set name
        let responseData = createTestResponseData()
        let questionSetName = ""
        let questionSetVersion = 1
        let eventProperties = createTestEventProperties()

        // Call the method with the expected parameters
        let result = await exitPollSurvey.cacheExitPollResponsesToSendLater(
            responseData: responseData,
            questionSetName: questionSetName,
            questionSetVersion: questionSetVersion,
            eventProperties: eventProperties
        )

        // Verify result - should fail with an error
        switch result {
        case .success:
            throw TestFailure("Caching operation should fail with empty question set name")
        case .failure(let error):
            let errorContainsExpectedText = error.localizedDescription.contains("empty question set name")
            #expect(errorContainsExpectedText)
        }
    }

    @Test
    func cachingWithInvalidURL() async {
        // Setup test environment
        let (_, exitPollSurvey, _) = createTestEnvironment()

        // Create test data
        let responseData = createTestResponseData()
        let questionSetName = "invalid/name/with/slashes"  // This might cause URL construction to fail
        let questionSetVersion = 1
        let eventProperties = createTestEventProperties()

        // Call the method with the expected parameters
        let result = await exitPollSurvey.cacheExitPollResponsesToSendLater(
            responseData: responseData,
            questionSetName: questionSetName,
            questionSetVersion: questionSetVersion,
            eventProperties: eventProperties
        )

        // The result could be success or failure depending on how your URL construction handles special characters
        if case .failure(let error) = result {
            let errorContainsExpectedText = error.localizedDescription.contains("URL")
            #expect(errorContainsExpectedText)
        }
    }

    @Test
    func sendAllAnswers() async throws {
        // Setup test environment
        let (_, exitPollSurvey, viewModel) = createTestEnvironment()

        // Configure mock network client to succeed
        exitPollSurvey.shouldSucceed = true

        // Configure view model with test data
        viewModel.setTestHook("test_hook")
        viewModel.questionSetName = "test_set"
        viewModel.questionSetVersion = 2
        viewModel.questionSetId = "test_id"

        // Create a test position
        let position: [Double] = [1.0, 2.0, 3.0]

        // When - Call the method
        try await exitPollSurvey.sendAllAnswers(
            using: viewModel,
            hook: viewModel.hook,
            sceneId: "test_scene",
            questionSetVersion: viewModel.questionSetVersion,
            position: position
        )

        // Then - Verify the request was made
        let endpointMatches = exitPollSurvey.lastEndpoint == "questionSets/test_set/2/responses"
        #expect(endpointMatches)

        // Compare HTTP method using string equality
        let methodIsPost = exitPollSurvey.lastMethod == "POST"
        #expect(methodIsPost)

        // Check body exists
        let bodyExists = exitPollSurvey.lastRawBody != nil
        #expect(bodyExists)
    }

    @Test
    func sendAllAnswersFailure() async throws {
        // Setup test environment
        let (_, exitPollSurvey, viewModel) = createTestEnvironment()

        // Configure mock network client to fail
        exitPollSurvey.shouldSucceed = false

        // Configure view model with test data
        viewModel.setTestHook("test_hook")
        viewModel.questionSetName = "test_set"
        viewModel.questionSetVersion = 2
        viewModel.questionSetId = "test_id"

        // Create a test position
        let position: [Double] = [1.0, 2.0, 3.0]

        // When/Then - Call the method and expect an error
        var receivedUnauthorizedError = false

        do {
            try await exitPollSurvey.sendAllAnswers(
                using: viewModel,
                hook: viewModel.hook,
                sceneId: "test_scene",
                questionSetVersion: viewModel.questionSetVersion,
                position: position
            )

            throw TestFailure("Should have thrown an error")
        } catch let error as APIError {
            // Instead of checking equality, check the specific type of error
            switch error {
            case .unauthorized:
                // Test passed - this is the expected error
                receivedUnauthorizedError = true
            default:
                throw TestFailure("Wrong error type: Expected unauthorized but got \(error)")
            }
        } catch let error as TestFailure {
            // Re-throw test failures
            throw error
        } catch {
            throw TestFailure("Unexpected error type: \(error)")
        }

        #expect(receivedUnauthorizedError)
    }

    @Test
    func clearCache() async throws {
        // Setup test environment
        let (mockCore, exitPollSurvey, _) = createTestEnvironment()

        // First cache some data
        let responseData = createTestResponseData()
        let questionSetName = "test_question_set"
        let questionSetVersion = 1
        let eventProperties = createTestEventProperties()

        // Store in cache
        let cacheResult = await exitPollSurvey.cacheExitPollResponsesToSendLater(
            responseData: responseData,
            questionSetName: questionSetName,
            questionSetVersion: questionSetVersion,
            eventProperties: eventProperties
        )

        // Verify caching was successful
        guard case .success = cacheResult else {
            throw TestFailure("Failed to cache data")
        }

        // Verify data is in cache
        if let cache = await mockCore.dataCacheSystem?.cache {
            let hasContent = cache.hasContent()
            #expect(hasContent)

            // Now clear the cache
            await mockCore.dataCacheSystem?.clearCache()

            // Verify cache is empty
            let isEmpty = !cache.hasContent()
            #expect(isEmpty)
        } else {
            throw TestFailure("Cache should be available")
        }
    }

    // MARK: - Helper Methods

    private func createTestEnvironment() -> (
        mockCore: MockCognitive3DAnalyticsCore,
        exitPollSurvey: TestExitPollSurvey,
        viewModel: TestExitPollSurveyViewModel
    ) {
        // Initialize with mock core that includes a data cache system
        let mockCore = MockCognitive3DAnalyticsCore(withTestDataCache: true)

        // Configure the mock core
        try? mockCore.configure(with: CoreSettings(apiKey: "test_key"))

        // Create the exit poll survey with the mock core
        let exitPollSurvey = TestExitPollSurvey(core: mockCore)

        // Initialize our test-specific view model
        let viewModel = TestExitPollSurveyViewModel()

        // Set up mock survey data in the view model
        setupMockSurveyData(viewModel: viewModel)

        return (mockCore, exitPollSurvey, viewModel)
    }

    private func setupMockSurveyData(viewModel: TestExitPollSurveyViewModel) {
        // Create some basic survey questions for the view model
        viewModel.surveyQuestions = [
            Question(
                type: .boolean,
                saveToSession: true,
                propertyLabel: "q1",
                title: "Test Question 1",
                answers: nil,
                minLabel: nil,
                maxLabel: nil,
                range: nil,
                maxResponseLength: nil
            ),
            Question(
                type: .scale,
                saveToSession: true,
                propertyLabel: "q2",
                title: "Test Question 2",
                answers: nil,
                minLabel: "Low",
                maxLabel: "High",
                range: Range(start: 1, end: 5),
                maxResponseLength: nil
            )
        ]

        // Set answers
        viewModel.surveyQuestions[0].answer = 1
        viewModel.surveyQuestions[1].answer = 3

        // Set other required properties
        viewModel.setTestHook("test_hook")
        viewModel.questionSetName = "test_question_set"
        viewModel.questionSetVersion = 1
        viewModel.questionSetId = "test_id"
        viewModel.title = "Test Survey"
    }

    private func createTestResponseData() -> Data {
        // Create a test response dictionary
        let response: [String: Any] = [
            "userId": "test_user",
            "questionSetId": "test_id",
            "sessionId": "test_session",
            "hook": "test_hook",
            "sceneId": "test_scene",
            "versionNumber": 1,
            "versionId": 1,
            "answers": [
                ["type": "BOOLEAN", "value": 1],
                ["type": "SCALE", "value": 3]
            ]
        ]

        // Convert to JSON data
        return try! JSONSerialization.data(withJSONObject: response)
    }

    private func createTestEventProperties() -> [String: Any] {
        // Create test event properties
        return [
            "userId": "test_user",
            "duration": 60.0,
            "questionSetId": "test_id",
            "hook": "test_hook",
            "sceneId": "test_scene",
            "Answer0": 1,
            "Answer1": 3
        ]
    }
}

/// Custom error type for test failures
struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
