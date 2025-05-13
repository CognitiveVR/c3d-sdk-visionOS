//
//  ExitPollCache.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Manages caching of exit poll questions
class ExitPollCache {
    private let cacheFilename: String

    init(path: String) {
        self.cacheFilename = path + "exitpoll_questions.json"
    }

    /// Cache exit poll questions for offline use
    /// - Parameter questionsData: The questions JSON data
    func cacheQuestions(_ questionsData: Data) {
        do {
            try questionsData.write(to: URL(fileURLWithPath: cacheFilename))
        } catch {
            print("Error caching exit poll questions: \(error)")
        }
    }

    /// Get cached exit poll questions
    /// - Returns: The cached questions data if available
    func getCachedQuestions() -> Data? {
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
