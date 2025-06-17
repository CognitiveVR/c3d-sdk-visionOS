//
//  NetworkDataCacheDelegate.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Implementation of DataCacheDelegate that uses NetworkAPIClient for uploads
class NetworkDataCacheDelegate: DataCacheDelegate {
    private let networkClient: NetworkAPIClient
    private let logger = CognitiveLog(category: "NetworkDataCacheDelegate")

    init(networkClient: NetworkAPIClient) {
        self.networkClient = networkClient
        // Inherit log level from network client if available
        let networkLogger = networkClient.getLog()
        logger.setLoggingLevel(level: networkLogger.currentLogLevel)
        logger.isDebugVerbose = networkLogger.isDebugVerbose
        logger.verbose("NetworkDataCacheDelegate: initialized")
    }

    func uploadCachedRequest(url: URL, body: Data, completion: @escaping (Bool) -> Void) {
        logger.info("Handling cached upload request for \(url.lastPathComponent)")

        // Create a properly configured URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        // Add headers from the network client to ensure proper authentication
        if let authHeader = networkClient.headers["Authorization"] {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Configure a session with better timeout behavior
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 5
        let session = URLSession(configuration: config)

        Task {
            do {
                logger.info("Preparing to upload cached data to '\(url.absoluteString)'")

                // Perform the request
                let (_, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    logger.error("Invalid response type")
                    await MainActor.run { completion(false) }
                    return
                }

                let isSuccess = (200...299).contains(httpResponse.statusCode)

                if isSuccess {
                    logger.info("Successfully uploaded cached data to '\(url.lastPathComponent)'")
                    await MainActor.run { completion(true) }
                } else {
                    logger.error("Server returned error status: \(httpResponse.statusCode)")
                    await MainActor.run { completion(false) }
                }
            } catch {
                logger.error("Network error: \(error.localizedDescription)")
                await MainActor.run { completion(false) }
            }
        }
    }

    func isValidResponse(_ response: HTTPURLResponse) -> Bool {
        return (200...299).contains(response.statusCode)
    }
}

/// Empty struct to use with generic NetworkAPIClient response
struct EmptyResponse: Decodable {
    // Empty struct to use when we don't care about the response data
    // but need a Decodable type for the NetworkAPIClient
}
