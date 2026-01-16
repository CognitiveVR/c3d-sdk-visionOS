//
//  ExitPollCache.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Manages caching of exit poll questions
class ExitPollCache {
    private let path: String

    init(path: String) {
        self.path = path
    }

    /// Cache exit poll questions for offline use
    /// - Parameter questionsData: The questions JSON data
    func cacheQuestions(hook: String,  questionsData: Data) {
        let cacheFilename = "\(path)/\(hook).json"
        do {
            try questionsData.write(to: URL(fileURLWithPath: cacheFilename))
        } catch {
            print("Error caching exit poll questions: \(error)")
        }
    }

    /// Get cached exit poll questions
    /// - Returns: The cached questions data if available
    func getCachedQuestions(hook: String) -> Data? {
        let cacheFilename = "\(path)/\(hook).json"
        guard FileManager.default.fileExists(atPath: cacheFilename) else {
            return nil
        }

        do {
            return try Data(contentsOf: URL(fileURLWithPath: cacheFilename))
        } catch {
            print("Error reading cached exit poll questions: \(error)")
            return nil
        }
    }
}
