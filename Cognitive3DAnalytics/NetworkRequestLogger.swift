//
//  NetworkRequestLogger.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// A record of a network request and its response
public struct NetworkRequestRecord: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let url: String
    public let method: String
    public let requestHeaders: [String: String]
    public let requestBody: String?
    public let statusCode: Int?
    public let responseHeaders: [String: String]?
    public let responseBody: String?
    public let error: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        url: String,
        method: String,
        requestHeaders: [String: String],
        requestBody: String? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String]? = nil,
        responseBody: String? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.error = error
    }
}

/// A logger for network requests and responses
public class NetworkRequestLogger {
    // MARK: - Properties

    /// Singleton instance
    public static let shared = NetworkRequestLogger()

    /// Maximum number of records to keep
    private var maxRecords: Int = 100

    /// Whether to enable network request logging
    private var isEnabled: Bool = false

    /// Records of network requests
    private var records: [NetworkRequestRecord] = []

    /// Logger for console output
    private var logger: CognitiveLog

    /// Whether to enable verbose logging
    private var isVerboseLogging: Bool = false

    private var verboseLogLevel = 1

    // MARK: - Initialization

    private init() {
        self.logger = CognitiveLog(category: "NetworkRequestLogger")
    }

    // MARK: - Configuration

    /// Configure the logger
    /// - Parameters:
    ///   - isEnabled: Whether to enable network request logging
    ///   - maxRecords: Maximum number of records to keep
    ///   - isVerboseLogging: Whether to enable verbose logging
    public func configure(isEnabled: Bool, maxRecords: Int = 100, isVerboseLogging: Bool = false) {
        self.isEnabled = isEnabled
        self.maxRecords = maxRecords
        self.isVerboseLogging = isVerboseLogging
        logger.isDebugVerbose = isVerboseLogging
    }

    /// Check if logging is enabled
    /// - Returns: Whether logging is enabled
    public func isLoggingEnabled() -> Bool {
        return isEnabled
    }

    // MARK: - Logging

    /// Log a network request
    /// - Parameters:
    ///   - url: URL of the request
    ///   - method: HTTP method of the request
    ///   - requestHeaders: Headers of the request
    ///   - requestBody: Body of the request
    public func logRequest(url: String, method: String, requestHeaders: [String: String], requestBody: Data?) {
        guard isEnabled else { return }

        let requestBodyString = requestBody.flatMap {
            prettyPrintJSON(data: $0) ?? String(data: $0, encoding: .utf8)
        }

        let record = NetworkRequestRecord(
            url: url,
            method: method,
            requestHeaders: requestHeaders,
            requestBody: requestBodyString
        )

        addRecord(record)

        if isVerboseLogging {
            logger.verbose("Network Request: \(method) \(url)")
            if verboseLogLevel > 1 {
                logger.verbose("Headers: \(requestHeaders)")
                if let body = requestBodyString {
                    logger.verbose("Body: \(body)")
                }
            }
        }
    }

    /// Update a network request record with response data
    /// - Parameters:
    ///   - url: URL of the request
    ///   - statusCode: HTTP status code of the response
    ///   - responseHeaders: Headers of the response
    ///   - responseBody: Body of the response
    public func logResponse(url: String, statusCode: Int, responseHeaders: [String: String]?, responseBody: Data?) {
        guard isEnabled else { return }

        let responseBodyString = responseBody.flatMap {
            prettyPrintJSON(data: $0) ?? String(data: $0, encoding: .utf8)
        }

        if let lastRecord = records.first, lastRecord.url == url, lastRecord.statusCode == nil {
            // Update the last record with response data
            let updatedRecord = NetworkRequestRecord(
                id: lastRecord.id,
                timestamp: lastRecord.timestamp,
                url: lastRecord.url,
                method: lastRecord.method,
                requestHeaders: lastRecord.requestHeaders,
                requestBody: lastRecord.requestBody,
                statusCode: statusCode,
                responseHeaders: responseHeaders,
                responseBody: responseBodyString
            )

            // Replace the first record with the updated one
            if let index = records.firstIndex(where: { $0.id == lastRecord.id }) {
                records[index] = updatedRecord
            }
        }

        if isVerboseLogging {
            logger.verbose("Network Response: \(statusCode) \(url)")
            if verboseLogLevel > 1 {
                if let headers = responseHeaders {
                    logger.verbose("Headers: \(headers)")
                }
                if let body = responseBodyString {
                    logger.verbose("Body: \(body)")
                }
            }
        }
    }

    /// Log an error for a network request
    /// - Parameters:
    ///   - url: URL of the request
    ///   - error: Error that occurred
    public func logError(url: String, error: Error) {
        guard isEnabled else { return }

        if let lastRecord = records.first, lastRecord.url == url, lastRecord.statusCode == nil {
            // Update the last record with error data
            let updatedRecord = NetworkRequestRecord(
                id: lastRecord.id,
                timestamp: lastRecord.timestamp,
                url: lastRecord.url,
                method: lastRecord.method,
                requestHeaders: lastRecord.requestHeaders,
                requestBody: lastRecord.requestBody,
                error: error.localizedDescription
            )

            // Replace the first record with the updated one
            if let index = records.firstIndex(where: { $0.id == lastRecord.id }) {
                records[index] = updatedRecord
            }
        }

        if isVerboseLogging {
            logger.error("Network Error for \(url): \(error.localizedDescription)")
        }
    }

    // MARK: - Record Management

    /// Add a record to the logger
    /// - Parameter record: Record to add
    private func addRecord(_ record: NetworkRequestRecord) {
        records.insert(record, at: 0)

        // Trim records if necessary
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
    }

    /// Clear all records
    public func clearRecords() {
        records.removeAll()
    }

    /// Get all records
    /// - Returns: All records
    public func getRecords() -> [NetworkRequestRecord] {
        return records
    }

    /// Get the most recent records
    /// - Parameter count: Number of records to get
    /// - Returns: Most recent records
    public func getRecentRecords(count: Int = 10) -> [NetworkRequestRecord] {
        return Array(records.prefix(min(count, records.count)))
    }

    // MARK: - Helpers

    /// Pretty print JSON data
    /// - Parameter data: JSON data to pretty print
    /// - Returns: Pretty printed JSON string
    private func prettyPrintJSON(data: Data) -> String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted])
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
