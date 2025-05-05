//
//  Cognitive3DAnalyticsCore+NetworkLogging.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

// Extension to add network logging functionality to Cognitive3DAnalyticsCore
extension Cognitive3DAnalyticsCore {
    /// Enable network request logging
    /// - Parameters:
    ///   - enabled: Whether to enable network request logging
    ///   - maxRecords: Maximum number of records to keep
    ///   - isVerboseLogging: Whether to enable verbose logging
    public func enableNetworkLogging(enabled: Bool, maxRecords: Int = 100, isVerboseLogging: Bool = false) {
        // Configure the NetworkRequestLogger
        NetworkRequestLogger.shared.configure(
            isEnabled: enabled,
            maxRecords: maxRecords,
            isVerboseLogging: isVerboseLogging
        )

        // Enable logging in the NetworkAPIClient if available
        if let client = networkClient {
            client.setNetworkLoggingEnabled(enabled)
        } else {
            logger?.warning("No NetworkAPIClient available for network logging")
        }

        // Log configuration
        logger?.info("Network logging configured - enabled: \(enabled), maxRecords: \(maxRecords), verbose: \(isVerboseLogging)")
    }

    /// Get the current state of network logging
    /// - Returns: Whether network logging is enabled
    public func isNetworkLoggingEnabled() -> Bool {
        // Check if the NetworkAPIClient is configured for logging
        if let client = networkClient {
            return client.isNetworkLoggingEnabled
        }

        // Check the NetworkRequestLogger state as fallback
        return NetworkRequestLogger.shared.isLoggingEnabled()
    }

    /// Get all network request records
    /// - Returns: All network request records
    public func getNetworkRequestRecords() -> [NetworkRequestRecord] {
        return NetworkRequestLogger.shared.getRecords()
    }

    /// Get the most recent network request records
    /// - Parameter count: Number of records to get
    /// - Returns: Most recent network request records
    public func getRecentNetworkRequestRecords(count: Int = 10) -> [NetworkRequestRecord] {
        return NetworkRequestLogger.shared.getRecentRecords(count: count)
    }

    /// Clear all network request records
    public func clearNetworkRequestRecords() {
        NetworkRequestLogger.shared.clearRecords()
    }

    /// Perform a diagnostic network request to test logging
    /// - Returns: Bool indicating if the test was successful
    @discardableResult
    public func performNetworkLoggingTest() -> Bool {
        guard let client = networkClient else {
            logger?.error("Cannot perform network logging test: Network client not initialized")
            return false
        }

        // Ensure logging is enabled
        enableNetworkLogging(enabled: true, maxRecords: 100, isVerboseLogging: true)

        // Create a dummy URLRequest to log
        if let url = URL(string: "https://diagnostic.cognitive3d.com/test") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = "{\"test\":true}".data(using: .utf8)

            // Log the request
            client.logNetworkRequest(url: url, method: .get, request: request)

            // Create a dummy response
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!

            let responseData = "{\"status\":\"success\",\"message\":\"diagnostic test\"}".data(using: .utf8)!

            // Log the response
            client.logNetworkResponse(url: url, response: response, data: responseData)

            logger?.info("Network logging diagnostic test performed - check records")
            return true
        }

        return false
    }

    /// Get diagnostic information about network logging
    /// - Returns: Dictionary with diagnostic information
    public func getNetworkLoggingDiagnostics() -> [String: Any] {
        let recordCount = NetworkRequestLogger.shared.getRecords().count

        var result: [String: Any] = [
            "recordCount": recordCount,
            "version": Cognitive3DAnalyticsCore.version
        ]

        if let client = networkClient {
            result["isNetworkClientAvailable"] = true
            result["isNetworkLoggingEnabled"] = client.isNetworkLoggingEnabled
        } else {
            result["isNetworkClientAvailable"] = false
        }

        return result
    }

    /// Alias method for backward compatibility
    public func configureNetworkLogging(enabled: Bool, maxRecords: Int = 100, isVerboseLogging: Bool = false) {
        enableNetworkLogging(enabled: enabled, maxRecords: maxRecords, isVerboseLogging: isVerboseLogging)
    }
}
