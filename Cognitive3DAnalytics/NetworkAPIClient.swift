//
//  NetworkAPIClient.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// Note: this name while generic should be fine while the enum is defined in a framework or Swift package.
public enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case encodingError(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unknown(Error)

    var description: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid Response"
        case .decodingError(let error):
            return "Decoding Error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding Error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized: Please check your API key"
        case .forbidden:
            return "Forbidden: You don't have permission to access this resource"
        case .notFound:
            return "Not Found: The requested resource doesn't exist"
        case .serverError(let code):
            // Handle specific server error codes with more helpful messages
            switch code {
            case 413:
                return "Request Too Large: The server cannot process this amount of data"
            case 502:
                return "Bad Gateway: The server received an invalid response while processing your request"
            case 500...599:
                return "Server Error: Unexpected status code \(code)"
            default:
                return "Server Error: Unexpected status code \(code)"
            }
        case .unknown(let error):
            return "Unknown Error: \(error.localizedDescription)"
        }
    }
}

/// The NetworkAPIClient handles the getting & postings of data to the Cognitive3D API.
class NetworkAPIClient {
    private let baseURL: String
    internal var headers: [String: String]
    private let logger = CognitiveLog(category: "NetworkClient")
    public var isDebugVerbose: Bool
    // Flag to enable network request logging
    internal var isNetworkLoggingEnabled: Bool = true

    init(apiKey: String, cog: Cognitive3DAnalyticsCore, isDebugVerbose: Bool = false) {
        self.baseURL = NetworkEnvironment.current.baseURL

        self.headers = [
            "Authorization": "APIKEY:DATA \(apiKey)",
            "Content-Type": "application/json",
        ]

        self.isDebugVerbose = isDebugVerbose
        logger.isDebugVerbose = isDebugVerbose
        // Inherit log level from core
        if let coreLogger = cog.logger {
            logger.setLoggingLevel(level: coreLogger.currentLogLevel)
        }
    }

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }

    private func validateResponseHeaders(_ httpResponse: HTTPURLResponse) -> Bool {
        if let requestTime = httpResponse.value(forHTTPHeaderField: "cvr-request-time") {
            logger.verbose("Request processing time: \(requestTime)ms")
            return true
        }
        logger.warning("No cvr-request-time header found - events should be cached")
        return false
    }

    /// Sends a network request and decodes the response into the specified type.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint relative to the base URL (e.g., "questionSets/basic").
    ///   - sceneId: Optional scene ID to include in the URL.
    ///   - version: Optional version parameter to include as a query string.
    ///   - method: The HTTP method for the request (default is `.post`).
    ///   - body: the type to be encoded as JSON
    ///   - timeoutInterval: the server timeout interval, if defaults to 60 seconds
    /// - Returns: Decoded response of type `T`, or `nil` if the response body is empty and `T` is optional.
    /// - Throws: `APIError` if the URL is invalid, encoding fails, or the server responds with an error.
    func makeRequest<T: Decodable, U: Encodable>(endpoint: String, sceneId: String, version: String, method: HTTPMethod = .post, body: U? = nil, timeoutInterval: TimeInterval = 5.0) async throws -> T {
        // Dynamically construct the URL to handle empty components
        var urlString = "\(baseURL)/\(endpoint)"


        if !sceneId.isEmpty {
            urlString += "/\(sceneId)"
        }

        if !version.isEmpty {
            urlString += "?version=\(version)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        logger.verbose("Making request to: \(urlString)")
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeoutInterval

        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        if let body = body, method == .post {
            do {
                request.httpBody = try JSONEncoder().encode(body)
                if isDebugVerbose {
                    do {
                        // Show only first 50 lines of JSON
                        let prettyJSON = try request.httpBody?.prettyPrintedJSON(maxLines: 50)
                        logger.info("Request body:\n\(prettyJSON ?? "nil")")
                    } catch {
                        logger.error("Failed to format request body: \(error)")
                    }
                }
            } catch {
                logger.error("Failed to encode request body: \(error)")
                throw APIError.encodingError(error)
            }
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: method, request: request)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            if logger.isDebugVerbose {
                debugLogHTTPResponse(httpResponse, data: data)
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            let shouldProcessEvents = validateResponseHeaders(httpResponse)
            logger.verbose("Response status code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:

                if isDebugVerbose {
                    // Log response headers
                    logger.info("Response Headers: \(httpResponse.allHeaderFields)")
                }

                if T.self == EventResponse.self {
                    return EventResponse(
                        status: String(httpResponse.statusCode),
                        received: shouldProcessEvents
                    ) as! T
                }

                if T.self == GazeResponse.self {
                    return GazeResponse(
                        status: String(httpResponse.statusCode),
                        received: shouldProcessEvents
                    ) as! T
                }

                if data.isEmpty {
                    if method == .post {
                        logger.info("Empty response body for valid POST request.")
                        // Handle empty response based on the type of T
                        if T.self == Void.self {
                            // Special case for Void return type
                            return () as! T
                        } else {
                            throw APIError.invalidResponse  // Adjust as needed for non-Optional types
                        }
                    } else {
                        logger.warning("Empty response body for \(method.rawValue) request.")
                        throw APIError.invalidResponse
                    }
                }

                guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                    contentType.contains("application/json")
                else {
                    throw APIError.invalidResponse
                }

                return try JSONDecoder().decode(T.self, from: data)

            case 401:
                logger.error("Unauthorized request: \(urlString)")
                throw APIError.unauthorized
            case 403:
                logger.error("Forbidden request: \(urlString)")
                throw APIError.forbidden
            case 404:
                if !sceneId.isEmpty {
                    logger.error("Resource not found: \(urlString) for scene \(sceneId)")
                } else {
                    logger.error("Resource not found: \(urlString)")
                }
                throw APIError.notFound
            default:
                logger.error("Server error (\(httpResponse.statusCode)) for request: \(urlString)")
                throw APIError.serverError(httpResponse.statusCode)
            }

        } catch let error as APIError {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }
            throw error
        } catch let error as DecodingError {
            logger.error("Decoding error: \(error)")
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }
            throw APIError.decodingError(error)
        } catch {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }
            throw APIError.networkError(error)
        }
    }

    /// Sends a network request and decodes the response into the specified type.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint relative to the base URL (e.g., "questionSets/basic").
    ///   - sceneId: Optional scene ID to include in the URL.
    ///   - version: Optional version parameter to include as a query string.
    ///   - method: The HTTP method for the request (default is `.post`).
    ///   - rawBody: the already encoded body to be sent in the request.
    /// - Returns: Decoded response of type `T`, or `nil` if the response body is empty and `T` is optional.
    /// - Throws: `APIError` if the URL is invalid, encoding fails, or the server responds with an error.
    func makeRequest<T: Decodable>(endpoint: String, sceneId: String, version: String, method: HTTPMethod = .post, rawBody: Data? = nil) async throws -> T? {
        // Construct the URL
        var urlString = "\(baseURL)/\(endpoint)"
        if !sceneId.isEmpty {
            urlString += "/\(sceneId)"
        }
        if !version.isEmpty {
            urlString += "?version=\(version)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        logger.verbose("Making request to: \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        // Attach raw body if provided
        if let rawBody = rawBody, method == .post {
            request.httpBody = rawBody
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: method, request: request)
        }

        do {
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            logger.verbose("Response status code: \(httpResponse.statusCode)")

            // Handle HTTP success cases
            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty {
                    if method == .post {
                        logger.info("Empty response body for valid POST request.")
                        return nil
                    } else {
                        logger.warning("Empty response body for \(method.rawValue) request.")
                        throw APIError.invalidResponse
                    }
                }

                guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
                      contentType.contains("application/json") else {
                    if method == .post && data.isEmpty {
                        return nil
                    }
                    throw APIError.invalidResponse
                }

                return try JSONDecoder().decode(T.self, from: data)

            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            default:
                let apiError = APIError.serverError(httpResponse.statusCode)
                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: apiError)
                }
                throw apiError
            }
        } catch {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }

            if let apiError = error as? APIError {
                throw apiError
            } else {
                throw APIError.networkError(error)
            }
        }
    }

    /// Sends a network request and decodes the response into the specified type.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint relative to the base URL (e.g., "questionSets/basic").
    ///   - sceneId: Optional scene ID to include in the URL.
    ///   - version: Optional version parameter to include as a query string.
    ///   - method: The HTTP method for the request (default is `.post`).
    ///   - body: the type to be encoded as JSON
    /// - Returns: Decoded response of type `T`, or `nil` if the response body is empty and `T` is optional.
    /// - Throws: `APIError` if the URL is invalid, encoding fails, or the server responds with an error.
    func makeRequestDebug<T: Decodable, U: Encodable>(endpoint: String, sceneId: String, version: String, method: HTTPMethod = .post, body: U? = nil) async throws -> T {
        // Construct the URL
        var urlString = "\(baseURL)/\(endpoint)"

        if !sceneId.isEmpty {
            urlString += "/\(sceneId)"
        }

        if !version.isEmpty {
            urlString += "?version=\(version)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        print("URL: \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
            print("Header: \(key): \(value)")
        }

        // Encode the body if provided
        if let body = body, method == .post {
            do {
                request.httpBody = try JSONEncoder().encode(body)
                if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                    print("Encoded JSON Body: \(jsonString)")
                }
            } catch {
                print("Failed to encode request body: \(error)")
                throw APIError.encodingError(error)
            }
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: method, request: request)
        }

        do {
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            print("Response Status Code: \(httpResponse.statusCode)")

            // Log response body if it exists
            if let responseBody = String(data: data, encoding: .utf8) {
                print("Response Body:\n\(responseBody)")
            } else {
                print("Response body is empty.")
            }

            // Handle HTTP success or failure
            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    print("Decoding Error: \(error)")
                    throw APIError.decodingError(error)
                }
            default:
                let apiError = APIError.serverError(httpResponse.statusCode)
                print("Server Error (\(httpResponse.statusCode)) for request: \(urlString)")
                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: apiError)
                }
                throw apiError
            }
        } catch {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }

            if let apiError = error as? APIError {
                throw apiError
            } else {
                throw APIError.networkError(error)
            }
        }
    }

    /// Sends a network request and decodes the response into the specified type.
    ///
    /// - Parameters:
    ///   - endpoint: The API endpoint relative to the base URL (e.g., "questionSets/basic").
    ///   - sceneId: Optional scene ID to include in the URL.
    ///   - version: Optional version parameter to include as a query string.
    ///   - method: The HTTP method for the request (default is `.post`).
    ///   - rawBody: The raw `Data` to be sent as the request body (useful for pre-encoded JSON).
    /// - Returns: Decoded response of type `T`, or `nil` if the response body is empty and `T` is optional.
    /// - Throws: `APIError` if the URL is invalid, or if the server responds with an error.
    func makeRequestDebug<T: Decodable>(
        endpoint: String, sceneId: String, version: String, method: HTTPMethod = .post, rawBody: Data? = nil
    ) async throws -> T? {
        // Construct the URL
        var urlString = "\(baseURL)/\(endpoint)"
        if !sceneId.isEmpty {
            urlString += "/\(sceneId)"
        }
        if !version.isEmpty {
            urlString += "?version=\(version)"
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        print("URL: \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Add headers
        headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
            print("Header: \(key): \(value)")
        }

        // Attach raw body if provided
        if let rawBody = rawBody, method == .post {
            request.httpBody = rawBody
            if let jsonString = String(data: rawBody, encoding: .utf8) {
                print("Final Raw JSON Body: \(jsonString)")
            } else {
                print("Failed to decode raw body as JSON.")
            }
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: method, request: request)
        }

        do {
            // Perform the network request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            print("Response Status Code: \(httpResponse.statusCode)")

            // Log response headers
            print("Response Headers: \(httpResponse.allHeaderFields)")

            // Handle HTTP success cases
            switch httpResponse.statusCode {
            case 200...299:
                if data.isEmpty {
                    print("Empty response body for valid \(method.rawValue) request.")
                    return nil  // Return nil for empty responses
                } else {
                    do {
                        return try JSONDecoder().decode(T.self, from: data)
                    } catch {
                        print("Decoding Error: \(error)")
                        throw APIError.decodingError(error)
                    }
                }

            default:
                let apiError = APIError.serverError(httpResponse.statusCode)
                print("Server Error (\(httpResponse.statusCode)) for request: \(urlString)")
                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: apiError)
                }
                throw apiError
            }
        } catch {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }

            if let apiError = error as? APIError {
                throw apiError
            } else {
                throw APIError.networkError(error)
            }
        }
    }

    /// Fetch data as plain text from the given URL
    func fetchDataAsText(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        logger.info("Fetching data as text from: \(urlString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: .get, request: request)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let apiError = APIError.serverError(httpResponse.statusCode)
                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: apiError)
                }
                throw apiError
            }

            guard let textResponse = String(data: data, encoding: .utf8) else {
                let error = NSError(domain: "Unable to decode response as text", code: 0, userInfo: nil)
                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: error)
                }
                throw APIError.decodingError(error)
            }

            return textResponse
        } catch {
            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }

            if let apiError = error as? APIError {
                throw apiError
            } else {
                throw APIError.networkError(error)
            }
        }
    }

    /// Uploads cached data to the specified URL
    /// - Parameters:
    ///   - url: The destination URL for the cached data
    ///   - body: The data to upload
    ///   - completion: Callback with success status, response, and any error
    func uploadCachedData(url: URL, body: Data, completion: @escaping (Bool, HTTPURLResponse?, Error?) -> Void) {
        logger.info("Preparing to upload cached data to '\(url.absoluteString)'")

        // Create the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        // Add headers
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        // Log request details at verbose level
        logger.verbose("Request URL: \(url.absoluteString)")
        logger.verbose("Request body size: \(body.count) bytes")

        // Check if it's exit poll data for specific logging
        let isExitPoll = url.absoluteString.contains("questionSets")
        if isExitPoll {
            logger.info("Uploading cached exit poll data")
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: .post, request: request)
        }

        // Execute the network request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                if isExitPoll {
                    self.logger.error("Failed to upload exit poll data: \(error.localizedDescription)")
                } else {
                    self.logger.error("Network request failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }

                // Log the network error if enabled
                if self.isNetworkLoggingEnabled {
                    self.logNetworkError(url: url, error: error)
                }

                completion(false, nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("Invalid response received (not HTTP)")
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])

                // Log the network error if enabled
                if self.isNetworkLoggingEnabled {
                    self.logNetworkError(url: url, error: error)
                }

                completion(false, nil, error)
                return
            }

            // Log the network response if enabled
            if self.isNetworkLoggingEnabled {
                self.logNetworkResponse(url: url, response: httpResponse, data: data ?? Data())
            }

            let isSuccess = 200...299 ~= httpResponse.statusCode

            // Check for captive portal by validating response headers
            let isValidResponse = self.validateResponseHeaders(httpResponse)
            if !isValidResponse {
                self.logger.warning("Response may be from a captive portal, treating as failure")
                let error = NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Possible captive portal response"])

                // Log the network error if enabled
                if self.isNetworkLoggingEnabled {
                    self.logNetworkError(url: url, error: error)
                }

                completion(false, httpResponse, error)
                return
            }

            if isSuccess {
                if isExitPoll {
                    self.logger.info("Successfully uploaded exit poll data, status: \(httpResponse.statusCode)")
                } else {
                    self.logger.info("Successfully uploaded cached data to '\(url.lastPathComponent)', status: \(httpResponse.statusCode)")
                }
            } else {
                if isExitPoll {
                    self.logger.error("Failed to upload exit poll data, status: \(httpResponse.statusCode)")
                } else {
                    self.logger.error("Failed to upload cached data to '\(url.lastPathComponent)', status: \(httpResponse.statusCode)")
                }

                // Log the network error if enabled
                if self.isNetworkLoggingEnabled {
                    let apiError = APIError.serverError(httpResponse.statusCode)
                    self.logNetworkError(url: url, error: apiError)
                }
            }

            completion(isSuccess, httpResponse, isSuccess ? nil : APIError.serverError(httpResponse.statusCode))
        }

        task.resume()
    }

    /// Uploads cached data to the specified URL using Swift concurrency
    /// - Parameters:
    ///   - url: The destination URL for the cached data
    ///   - body: The data to upload
    /// - Returns: A tuple with success status, HTTP response, and error
    func uploadCachedDataAsync(url: URL, body: Data) async -> (Bool, HTTPURLResponse?, Error?) {
        logger.info("Preparing to upload cached data to '\(url.absoluteString)'")

        // Create the URL request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body

        // Add headers
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        // Log request details at verbose level
        logger.verbose("Request URL: \(url.absoluteString)")
        logger.verbose("Request body size: \(body.count) bytes")

        // Check if it's exit poll data for specific logging
        let isExitPoll = url.absoluteString.contains("questionSets")
        if isExitPoll {
            logger.info("Uploading cached exit poll data")
        }

        // Log the network request if enabled
        if isNetworkLoggingEnabled {
            logNetworkRequest(url: url, method: .post, request: request)
        }

        do {
            // Execute the network request using async/await
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Invalid response received (not HTTP)")
                let error = NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])

                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: error)
                }

                return (false, nil, error)
            }

            // Log the network response if enabled
            if isNetworkLoggingEnabled {
                logNetworkResponse(url: url, response: httpResponse, data: data)
            }

            let isSuccess = 200...299 ~= httpResponse.statusCode

            // Check for captive portal by validating response headers
            let isValidResponse = validateResponseHeaders(httpResponse)
            if !isValidResponse {
                logger.warning("Response may be from a captive portal, treating as failure")
                let error = NSError(domain: "NetworkError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Possible captive portal response"])

                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    logNetworkError(url: url, error: error)
                }

                return (false, httpResponse, error)
            }

            if isSuccess {
                if isExitPoll {
                    logger.info("Successfully uploaded exit poll data, status: \(httpResponse.statusCode)")
                } else {
                    logger.info("Successfully uploaded cached data to '\(url.lastPathComponent)', status: \(httpResponse.statusCode)")
                }
            } else {
                if isExitPoll {
                    logger.error("Failed to upload exit poll data, status: \(httpResponse.statusCode)")
                } else {
                    logger.error("Failed to upload cached data to '\(url.lastPathComponent)', status: \(httpResponse.statusCode)")
                }

                // Log the network error if enabled
                if isNetworkLoggingEnabled {
                    let apiError = APIError.serverError(httpResponse.statusCode)
                    logNetworkError(url: url, error: apiError)
                }

                return (false, httpResponse, APIError.serverError(httpResponse.statusCode))
            }

            return (isSuccess, httpResponse, nil)

        } catch {
            if isExitPoll {
                logger.error("Failed to upload exit poll data: \(error.localizedDescription)")
            } else {
                logger.error("Network request failed for '\(url.lastPathComponent)': \(error.localizedDescription)")
            }

            // Log the network error if enabled
            if isNetworkLoggingEnabled {
                logNetworkError(url: url, error: error)
            }

            return (false, nil, error)
        }
    }

    // MARK: -

    /// Enable or disable network request logging
    /// - Parameter enabled: Whether to enable network request logging
    internal func setNetworkLoggingEnabled(_ enabled: Bool) {
        isNetworkLoggingEnabled = enabled
        logger.verbose("Network request logging \(enabled ? "enabled" : "disabled")")
    }

    internal func getLog() -> CognitiveLog {
        return logger
    }

    /// Logs the headers and body of an HTTP response for debugging purposes.
    func debugLogHTTPResponse(_ response: HTTPURLResponse, data: Data?) {
        logger.info("Response Headers:")
        for (key, value) in response.allHeaderFields {
            logger.info("  \(key): \(value)")
        }

        if let data = data, !data.isEmpty {
            if let bodyString = String(data: data, encoding: .utf8) {
                logger.info("Response Body:\n\(bodyString)")
            } else {
                logger.info("Response Body (non-UTF8, \(data.count) bytes)")
            }
        }
    }
}

// Extension to add JSON pretty printing capability to Data
extension Data {
    func prettyPrintedJSON(maxLines: Int = Int.max) throws -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: self),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
              var string = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        if maxLines < Int.max {
            let lines = string.components(separatedBy: "\n")
            if lines.count > maxLines {
                let truncatedLines = Array(lines.prefix(maxLines))
                string = truncatedLines.joined(separator: "\n") + "\n... (truncated)"
            }
        }

        return string
    }
}
