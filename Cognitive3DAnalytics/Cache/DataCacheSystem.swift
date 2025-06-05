//
//  DataCacheSystem.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Error type for cache initialization failures
public enum DataCacheSystemError: Error {
    case failedToCreateCache
    case invalidCachePath

    var localizedDescription: String {
        switch self {
        case .failedToCreateCache:
            return "Failed to initialize DataCacheSystem: Could not create cache"
        case .invalidCachePath:
            return "Invalid cache path provided"
        }
    }
}

/// Protocol defining cache operations
public protocol CacheProtocol {
    /// Returns the number of batches in the cache
    func numberOfBatches() -> Int

    /// Returns true if there's content in the cache
    func hasContent() -> Bool

    /// Peeks at the next content, returning true if content exists
    func peekContent(destination: inout String, body: inout String) -> Bool

    /// Writes content to the cache, returns true if successful
    func writeContent(destination: String, body: String) -> Bool

    /// Writes raw content to the cache, returns true if successful
    func writeContent(_ content: String) -> Bool

    /// Removes the most recently peeked content
    func popContent()

    /// Closes the cache files
    func close()

    /// Checks if content can be written to the cache
    func canWrite(destination: String, body: String) -> Bool

    /// Checks if raw content can be written to the cache
    func canWrite(_ content: String) -> Bool

    /// Returns the cache fill percentage (0-1)
    func getCacheFillAmount() -> Float
}

/// Delegate protocol for handling cache upload events
protocol DataCacheDelegate: AnyObject {
    /// Called when cached content needs to be uploaded
    func uploadCachedRequest(url: URL, body: Data, completion: @escaping (Bool) -> Void)

    /// Validates if a response appears genuine (not from a captive portal)
    func isValidResponse(_ response: HTTPURLResponse) -> Bool
}

/// A cache system that handles storing data when network connectivity issues occur
/// Using an actor for thread-safe access to mutable state
public actor DataCacheSystem {
    // MARK: - Properties
    public var cache: DualFileCache?
    weak var delegate: DataCacheDelegate?

    /// In-memory cache as fallback when file cache isn't available
    private var inMemoryCache = [(destination: String, body: String)]()

    /// Interval (in seconds) to wait before retrying uploads after a network error.
    static let backoffInterval: TimeInterval = 10.0
    private var lastErrorTime: Date?
    private var isUploading = false
    private var isInitialized = false
    private let logger = CognitiveLog(category: "DataCacheSystem")

    /// Flag to control whether automatic upload attempts should be made
    private var shouldAttemptUpload: Bool = true

    /// Flag to control whether automatic upload attempts should be made during an active session
    private var shouldAttemptMidSessionUpload: Bool = true

    // MARK: - Initialization

    /// Initializes the DataCacheSystem
    /// Logs errors and falls back to in-memory cache if initialization fails.
    public init() {
        // Get document directory path before initializing other properties
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cachePath = documentsDirectory.path + "/"

        do {
            // Try to initialize the cache with the path
            self.cache = try DualFileCache(path: cachePath)
            self.isInitialized = true

            // Log initialization if logger is available
            if let coreLogger = Cognitive3DAnalyticsCore.shared.logger {
                if coreLogger.isDebugVerbose {
                    logger.info("Init DataCacheSystem with path \(cachePath)")
                }

                // Set the logger's log level to match the core logger
                logger.setLoggingLevel(level: coreLogger.currentLogLevel)
            }

            // Log cached content status during initialization
            if let cache = self.cache, cache.hasContent() {
                logger.info("Found existing cached content during initialization. Entries: \(cache.numberOfBatches())")
            } else {
                logger.info("No cached content found during initialization")
            }
        } catch {
            logger.error("Failed to initialize cache: \(error.localizedDescription). Using in-memory cache.")

            // We'll still be initialized, just without a file cache
            self.isInitialized = true
        }
    }

    func setDelegate(_ newDelegate: DataCacheDelegate?) async {
        self.delegate = newDelegate
    }

    /// Sets whether the system should attempt to upload data automatically
    /// - Parameter value: true to enable automatic upload attempts, false to only cache
    public func setShouldAttemptUpload(_ value: Bool) {
        self.shouldAttemptUpload = value
        logger.info("Auto-upload behavior set to: \(value ? "enabled" : "disabled")")
    }

    /// Sets whether the system should attempt to upload data during an active session
    /// - Parameter value: true to enable mid-session upload attempts, false to only upload at session start/end
    public func setShouldAttemptMidSessionUpload(_ value: Bool) {
        self.shouldAttemptMidSessionUpload = value
        logger.info("Mid-session upload behavior set to: \(value ? "enabled" : "disabled")")
    }

    /// Gets the current mid-session upload setting
    /// - Returns: true if mid-session uploads are enabled
    public func getShouldAttemptMidSessionUpload() -> Bool {
        return shouldAttemptMidSessionUpload
    }

    /// Gets the current auto-upload setting
    /// - Returns: true if automatic uploads are enabled
    public func getShouldAttemptUpload() -> Bool {
        return shouldAttemptUpload
    }

    /// Sets a custom cache path - useful for testing
    /// - Parameter path: The path where cache files should be stored
    /// - Throws: DataCacheSystemError if cache creation fails
    public func setCachePath(_ path: String) throws {
        try validateCachePathOrThrow(path)

        do {
            // Create a new cache with the specified path
            self.cache = try DualFileCache(path: path)
            self.isInitialized = true
        } catch {
            throw DataCacheSystemError.failedToCreateCache
        }
    }

    /// Validates that a cache path exists and is usable
    /// - Parameter path: Path to validate
    /// - Throws: DataCacheSystemError if path is invalid
    private func validateCachePathOrThrow(_ path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            throw DataCacheSystemError.invalidCachePath
        }
    }

    // MARK: - Public API

    /// Handle a network request, either by sending it or caching it if needed
    /// - Parameters:
    ///   - url: The API endpoint URL
    ///   - body: The JSON data to send
    /// - Returns: Success or failure of the request
    public func handleRequest(url: URL, body: Data) async -> Bool {
        // Log request handling
        logger.info("Handling request to '\(url.lastPathComponent)'")

        // If auto-upload is disabled, just cache without attempting network request
        if !shouldAttemptUpload {
            logger.info("Auto-upload disabled, caching request without network attempt")
            await cacheRequest(url: url, body: body)
            return false
        }

        // Check if we're in backoff period after an error
        if let lastError = lastErrorTime,
           Date().timeIntervalSince1970 - lastError.timeIntervalSince1970 < DataCacheSystem.backoffInterval {
            // We're in backoff period, cache directly without attempting network request
            logger.info("In backoff period after error, caching request without network attempt")
            await cacheRequest(url: url, body: body)
            return false
        }

        // Attempt to send the request through the delegate
        logger.info("Attempting to send request to '\(url.lastPathComponent)'")

        let success = await uploadCachedRequestAsync(url: url, body: body)

        if success {
            // If successful, try uploading any cached content
            logger.info("Request to '\(url.lastPathComponent)' successful, attempting to upload cached content")
            if shouldAttemptUpload {
                await uploadCachedContent()
            }
            return true
        } else {
            // Cache the failed request
            logger.info("Request to '\(url.lastPathComponent)' failed, caching for later upload")
            lastErrorTime = Date()
            await cacheRequest(url: url, body: body)
            return false
        }
    }

    /// Send a request and also immediately cache it (for cases like session ending)
    /// - Parameters:
    ///   - url: The API endpoint URL
    ///   - body: The JSON data to send
    public func sendAndCacheRequest(url: URL, body: Data) async {
        // First cache it immediately
        logger.info("Caching request to \(url.lastPathComponent) before attempting to send")
        await cacheRequest(url: url, body: body)

        // Then try to send it through the delegate if auto-upload is enabled
        if shouldAttemptUpload {
            logger.info("Attempting to send cached request to \(url.lastPathComponent)")
            let success = await uploadCachedRequestAsync(url: url, body: body)

            if success {
                logger.info("Successfully sent request to \(url.lastPathComponent)")
            } else {
                logger.info("Failed to send request to \(url.lastPathComponent), but already cached")
            }
        } else {
            logger.info("Auto-upload disabled, request cached but not sent to \(url.lastPathComponent)")
        }
    }

    // MARK: - Cache Management

    /// Caches a request by writing it to the write file
    /// - Parameters:
    ///   - url: The API endpoint URL
    ///   - body: The JSON data to send
    internal func cacheRequest(url: URL, body: Data) async {
        // Convert body to string and escape newlines
        guard let bodyString = String(data: body, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r") else {
            logger.error("Failed to encode body data")
            return
        }

        if let cache = cache {
            // Check if we can write to the cache
            if !cache.canWrite(destination: url.absoluteString, body: bodyString) {
                logger.warning("Cache size limit reached. Some data will be lost.")
                return
            }

            // Write to the cache using the DualFileCache - check result
            let writeSuccess = cache.writeContent(destination: url.absoluteString, body: bodyString)
            if writeSuccess {
                print("data written to cache for \(url.absoluteString)")
            } else {
                print("did NOT write to cache for \(url.absoluteString)")
            }
        } else {
            // Using in-memory cache as a fallback
            inMemoryCache.append((destination: url.absoluteString, body: bodyString))

            // Prevent in-memory cache from growing too large (limit to 100 entries)
            if inMemoryCache.count > 100 {
                inMemoryCache.removeFirst()
            }
        }
    }

    /// Uploads cached content from the read file to the backend
    public func uploadCachedContent() async {
        // Skip upload if auto-upload is disabled
        if !shouldAttemptUpload {
            logger.info("Auto-upload disabled, skipping cached content upload")
            return
        }

        // Prevent multiple simultaneous upload attempts
        guard !isUploading else {
            logger.info("Upload already in progress, skipping new upload request")
            return
        }

        // First check if there's content to upload
        if let cache = cache, cache.hasContent() {
            isUploading = true
            logger.info("File cache has content & will start uploading")
        } else if !inMemoryCache.isEmpty {
            isUploading = true
            logger.info("Memory cache has \(inMemoryCache.count) entries & will start uploading")
        } else {
            logger.verbose("No cached content to upload")
            return
        }

        // Now try to upload the next entry
        await uploadNextCachedEntry()
    }

    /// Uploads the next cached entry from the read file
    private func uploadNextCachedEntry() async {
        // Skip if auto-upload is disabled
        if !shouldAttemptUpload {
            isUploading = false
            return
        }

        // Check if we should use in-memory cache
        if cache == nil || !(cache?.hasContent() ?? false) {
            if inMemoryCache.isEmpty {
                isUploading = false
                logger.info("No more entries to upload, setting upload flag to false")
                return
            }

            // Use in-memory cache
            let entry = inMemoryCache.first!
            let urlString = entry.destination
            let bodyString = entry.body

            // Check if it's exit poll data
            let isExitPoll = urlString.contains("questionSets")
            if isExitPoll {
                logger.info("Processing exit poll data from in-memory cache")
            }

            // Process this entry
            await processAndUploadCachedEntry(urlString: urlString, bodyString: bodyString, fromInMemoryCache: true)
            return
        }

        // Using file cache
        var urlString = ""
        var bodyString = ""

        // Peek at the next content in the cache
        if !(cache?.peekContent(destination: &urlString, body: &bodyString) ?? false) {
            isUploading = false
            logger.info("No more entries to upload from file cache, setting upload flag to false")
            return
        }

        // Check if it's exit poll data
        let isExitPoll = urlString.contains("questionSets")
        if isExitPoll {
            logger.info("Processing exit poll data from file cache")
        }

        // Process this entry
        await processAndUploadCachedEntry(urlString: urlString, bodyString: bodyString, fromInMemoryCache: false)
    }

    /// Process and upload a cached entry
    private func processAndUploadCachedEntry(urlString: String, bodyString: String, fromInMemoryCache: Bool) async {
        // Skip if auto-upload is disabled
        if !shouldAttemptUpload {
            isUploading = false
            return
        }

        logger.info("upload cached content to \(urlString)")
        logger.verbose("content \(bodyString)")

        // Restore escaped newlines
        let restoredBodyString = bodyString
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\r")

        guard let url = URL(string: urlString),
              let bodyData = restoredBodyString.data(using: .utf8) else {
            // Remove invalid entry and continue with next
            if fromInMemoryCache {
                if !inMemoryCache.isEmpty {
                    inMemoryCache.removeFirst()
                }
                await uploadNextCachedEntry()
            } else {
                cache?.popContent()
                await uploadNextCachedEntry()
            }
            return
        }

        // Forward to delegate to handle the upload
        let success = await uploadCachedRequestAsync(url: url, body: bodyData)

        if success {
            // Success, remove entry from cache
            if fromInMemoryCache {
                if !inMemoryCache.isEmpty {
                    inMemoryCache.removeFirst()
                }
            } else {
                cache?.popContent()
            }

            // Continue with next entry
            await uploadNextCachedEntry()
        } else {
            // Failed, stop uploading for now
            isUploading = false
            logger.info("Stopping upload process due to failure, setting upload flag to false")
        }
    }

    /// Async wrapper for uploadCachedRequest that returns a boolean
    private func uploadCachedRequestAsync(url: URL, body: Data) async -> Bool {
        // Skip if auto-upload is disabled
        if !shouldAttemptUpload {
            return false
        }

        // Ensure we have a delegate before creating a continuation
        guard let delegate = self.delegate else {
            logger.error("No delegate available for uploading cached request to '\(url.absoluteString)'")
            logger.error("The local data cache will not function without a delegate")
            return false
        }

        return await withCheckedContinuation { continuation in
            delegate.uploadCachedRequest(url: url, body: body) { success in
                continuation.resume(returning: success)
            }
        }
    }

    // For unit tests
    internal func clearCache() async {
        if let cache = cache {
            while cache.hasContent() {
                cache.popContent()
            }
            logger.info("Cleared file cache")
        }

        inMemoryCache.removeAll()
        logger.info("Cleared in-memory cache")
    }

    // MARK: - Data Type Specific Methods

    /// Send exit poll answers
    /// - Parameters:
    ///   - questionSetName: the name for the question state associated with the current hook
    ///   - version: the version number for the question set
    ///   - pollData: The poll data payload
    /// - Returns: Success or failure of the request
    ///
    ///  The question set name and version are used to construct the URL to post the data to in the C3D back end
    public func sendExitPollAnswers(questionSetName:String, version: Int, pollData: Data) async -> Bool {
        guard let url = NetworkEnvironment.current.constructExitPollURL(questionSetName: questionSetName, version: version) else {
            logger.error("Failed to create URL for exit poll answers")
            return false
        }

        logger.info("Sending exit poll data - size: \(pollData.count) bytes")
        return await handleRequest(url: url, body: pollData)
    }
}
