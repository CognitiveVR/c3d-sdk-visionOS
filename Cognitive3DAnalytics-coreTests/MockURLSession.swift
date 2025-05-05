//
//  MockURLSession.swift
//
//  Created by Manjit Bedi
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import XCTest

protocol URLSessionProtocol: Sendable {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask
}

extension URLSession: URLSessionProtocol { }

/// Mock URL session used for unit testing
class MockURLSession: @unchecked Sendable, URLSessionProtocol {
    // Using actor-isolated properties in a class marked as @unchecked Sendable
    // This is safe for testing purposes since tests run sequentially
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    private let session: URLSession
    var lastRequest: URLRequest?

    init() {
        self.session = URLSession(configuration: .ephemeral)
    }

    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void
    ) -> URLSessionDataTask {
        // Capture the current values to avoid Sendable issues
        let currentMockData = mockData
        let currentMockResponse = mockResponse
        let currentMockError = mockError

        lastRequest = request
        return session.dataTask(with: request) { _, _, _ in
            // Use the captured values instead of directly accessing properties
            completionHandler(currentMockData, currentMockResponse, currentMockError)
        }
    }
}
