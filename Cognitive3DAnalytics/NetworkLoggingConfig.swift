//
//  NetworkLoggingConfig.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Configuration for network request logging
public struct NetworkLoggingConfig {
    /// Whether to enable network request logging
    public var isEnabled: Bool = false

    /// Maximum number of network request records to keep
    public var maxRecords: Int = 100

    /// Whether to enable verbose logging
    public var isVerboseLogging: Bool = false

    /// Initialize with default values
    public init(isEnabled: Bool = false, maxRecords: Int = 100, isVerboseLogging: Bool = false) {
        self.isEnabled = isEnabled
        self.maxRecords = maxRecords
        self.isVerboseLogging = isVerboseLogging
    }
}
