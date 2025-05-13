//
//  NetworkAPIClient+Logging.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// Extension to add network logging methods to NetworkAPIClient
extension NetworkAPIClient {

    /// Log a network request
    /// - Parameters:
    ///   - url: URL of the request
    ///   - method: HTTP method of the request
    ///   - request: URLRequest object
    internal func logNetworkRequest(url: URL, method: HTTPMethod, request: URLRequest) {
        var headersDict = [String: String]()
        if let allHTTPHeaderFields = request.allHTTPHeaderFields {
            headersDict = allHTTPHeaderFields
        }

        NetworkRequestLogger.shared.logRequest(
            url: url.absoluteString,
            method: method.rawValue,
            requestHeaders: headersDict,
            requestBody: request.httpBody
        )
    }

    /// Log a network response
    /// - Parameters:
    ///   - url: URL of the request
    ///   - response: HTTP URL response
    ///   - data: Response data
    internal func logNetworkResponse(url: URL, response: HTTPURLResponse, data: Data) {
        var headersDict = [String: String]()
        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                headersDict[keyString] = valueString
            }
        }

        NetworkRequestLogger.shared.logResponse(
            url: url.absoluteString,
            statusCode: response.statusCode,
            responseHeaders: headersDict,
            responseBody: data
        )
    }

    /// Log a network error
    /// - Parameters:
    ///   - url: URL of the request
    ///   - error: Error that occurred
    internal func logNetworkError(url: URL, error: Error) {
        NetworkRequestLogger.shared.logError(
            url: url.absoluteString,
            error: error
        )
    }
}
