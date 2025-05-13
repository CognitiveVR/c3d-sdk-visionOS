//
//  TestHelpers.swift
//  Cognitive3DAnalytics-coreTests
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation
@testable import Cognitive3DAnalytics

/// Test specific class for ExitPollSurvey with a testable API
class TestExitPollSurvey: ExitPollSurvey {
    // We need a reference to a mock network client
    private let mockClient: MockNetworkAPIClient

    override init(core: Cognitive3DAnalyticsCore) {
        // Create the mock client
        let apiKey = core.getConfig().applicationKey
        self.mockClient = MockNetworkAPIClient(apiKey: apiKey, cog: core)

        // Call parent initializer
        super.init(core: core)

        // Swizzle the networkClient property - using a technique that doesn't directly change the let property
        // Instead, we'll use our mock client directly in test methods
    }

    // Public API to access and manipulate the mock client
    var shouldSucceed: Bool {
        get { return mockClient.shouldSucceed }
        set { mockClient.shouldSucceed = newValue }
    }

    var lastEndpoint: String? {
        return mockClient.lastEndpoint
    }

    var lastMethod: String? {
        return mockClient.lastMethod?.rawValue
    }

    var lastRawBody: Data? {
        return mockClient.lastRawBody
    }

    // Override the actual network methods to use our mock client
    override func fetchExitPollQuestions(hook: String) async -> Result<ExitPollResponse, APIError> {
        let endpoint = "questionSetHooks/\(hook)/questionSet"

        do {
            let response: ExitPollResponse = try await mockClient.makeRequest(
                endpoint: endpoint,
                sceneId: "",
                version: "",
                method: .get,
                body: nil as String?
            )

            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.networkError(error))
        }
    }

    override func sendAllAnswers(using viewModel: ExitPollSurveyViewModel, hook: String, sceneId: String, questionSetVersion: Int, position: [Double]?) async throws {
        let fullResponse = viewModel.prepareJSONResponse(hook: hook, sceneId: sceneId, questionSetVersion: questionSetVersion, position: position)
        let endPoint = "questionSets/\(viewModel.questionSetName)/\(questionSetVersion)/responses"

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: fullResponse, options: [])

            let _: ExitPollResponse? = try await mockClient.makeRequest(
                endpoint: endPoint,
                sceneId: "",
                version: "",
                method: .post,
                rawBody: jsonData
            )
        } catch {
            throw error
        }
    }
}

/// View model subclass with a settable hook property for testing
class TestExitPollSurveyViewModel: ExitPollSurveyViewModel {
    // Override the hook property to make it publicly settable for testing
    private var _testHook: String = ""

    override var hook: String {
        get { return _testHook }
    }

    func setTestHook(_ value: String) {
        _testHook = value
    }
}
