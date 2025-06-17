//
//  CognitiveLog.swift
//  Cognitive3DAnalytics
//
//  Created by Calder Archinuk on 2024-11-18.
//
//  Copyright (c) 2024-2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation
import OSLog

public enum LogLevel: Int, Comparable {
    case all = 0
    case warningsAndErrors = -1
    case errorsOnly = -2
    case none = -3

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Logging class used by the C3D SDK. See also the enum  ``LogLevel``.
public class CognitiveLog {
    public var currentLogLevel: LogLevel = .all

    /// The  logger available on Apple platforms for the unified logging system.
    private let logger: Logger

    internal var isLongTextTrimmed = true

    ///  Setting the debug level to verbose will print out additional debug and configure the log level to all.
    public var isDebugVerbose = false {
        didSet {
            if isDebugVerbose {
                currentLogLevel = .all
            }
        }
    }

    // TODO: review the implementation & also the use of a subsystem.
    public init(category: String = "default") {
        logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "com.cognitive3d.analytics",
            category: category)
    }

    public func setLoggingLevel(level: LogLevel) {
        currentLogLevel = level
    }

    public func info(_ message: String) {
        guard currentLogLevel >= .all else { return }
        logger.info("ℹ️ \(message)")
    }

    public func warning(_ message: String) {
        guard currentLogLevel >= .warningsAndErrors else { return }
        logger.warning("⚠️ \(message)")
    }

    public func error(_ message: String) {
        guard currentLogLevel >= .errorsOnly else { return }
        logger.error("❌ \(message)")
    }

    public func verbose(_ message: String) {
        guard currentLogLevel >= .all else { return }
        if isDebugVerbose {
            // check string length
            let displayMessage: String
            if isLongTextTrimmed, message.count > 100 {
                // Trim to 97 characters and add "..."
                displayMessage = message.prefix(97) + "..."
            } else {
                displayMessage = message
            }

            logger.info("🗯️ VERBOSE: \(displayMessage)")
        }
    }

    /// Creates a formatted debug message with key-value pairs
    public func formatDebug(_ title: String, _ fields: [String: Any]) {
        verbose("""
        \(title):
        \(fields.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
        """)
    }

    /// Creates a formatted debug message with sensor data
    public func formatSensor(name: String, value: Double, timestamp: Double) {
        formatDebug("Recording sensor reading", [
            "Sensor": name,
            "Value": value,
            "Timestamp": timestamp
        ])
    }
}
