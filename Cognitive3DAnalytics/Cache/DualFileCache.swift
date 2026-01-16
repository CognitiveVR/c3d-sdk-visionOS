//
//  DualFileCache.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Error type for DualFileCache initialization failures
public enum DualFileCacheError: Error {
    case directoryCreationFailed
    case fileCreationFailed
    case fileHandleCreationFailed

    var localizedDescription: String {
        switch self {
        case .directoryCreationFailed:
            return "Failed to create cache directory"
        case .fileCreationFailed:
            return "Failed to create cache files"
        case .fileHandleCreationFailed:
            return "Failed to create file handles for cache"
        }
    }
}

/// Implementation of the CacheProtocol that manages two separate files for reading and writing
public class DualFileCache: CacheProtocol {
    // MARK: - Properties

    private let readFilename: String
    private let writeFilename: String
    private let maxCacheSize: UInt64 = 100 * 1024 * 1024 // 100MB default
    private let eolChar = "\n"

    // Keep track of lines in read file
    private var readLineLengths = [Int]()
    private var readLineLengthTotal = 0

    // File handles
    private var readFileHandle: FileHandle?
    private var writeFileHandle: FileHandle?

    // Number of batches in write file
    private var numberOfWriteBatches = 0

    // Current size of cache files
    private var currentCacheSize: UInt64 = 0

    // Flag to avoid repeated warnings
    private var displayedSizeWarning = false

    // Track if cache is closed
    private var isClosed = false

    // For debug
    private let logger = CognitiveLog(category: "DualFileCache")

    // MARK: - Initialization

    /// Initialize with the path where cache files should be stored
    /// - Parameter path: Directory path where cache files will be stored
    /// - Throws: DualFileCacheError if initialization fails
    init(path: String) throws {
        let finalPath = path.hasSuffix("/") ? path : path + "/"

        self.readFilename = finalPath + "data_read"
        self.writeFilename = finalPath + "data_write"

        logger.verbose("Initializing DualFileCache with path: \(finalPath)")

        try setupDirectories(at: finalPath)
        try setupFileHandles()

        // Count batches in write file
        countWriteBatches()

        // Merge write file into read file if there's content
        if numberOfWriteBatches > 0 {
            logger.info("Found \(numberOfWriteBatches) batches in write file, merging into read file")
            mergeDataFiles()
        }

        // Calculate initial cache size
        updateCurrentCacheSize()

        // Initialize readLineLengths
        initializeReadLineLengths()
    }

    private func setupDirectories(at path: String) throws {
        if !FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                logger.info("Created directory at \(path)")
            } catch {
                logger.error("Failed to create directory: \(error.localizedDescription)")
                throw DualFileCacheError.directoryCreationFailed
            }
        }

        if !FileManager.default.fileExists(atPath: readFilename) {
            if !FileManager.default.createFile(atPath: readFilename, contents: nil) {
                logger.error("Failed to create read file at \(readFilename)")
                throw DualFileCacheError.fileCreationFailed
            }
            logger.info("Created read file at \(readFilename)")
        }

        if !FileManager.default.fileExists(atPath: writeFilename) {
            if !FileManager.default.createFile(atPath: writeFilename, contents: nil) {
                logger.error("Failed to create write file at \(writeFilename)")
                throw DualFileCacheError.fileCreationFailed
            }
            logger.info("Created write file at \(writeFilename)")
        }
    }

    private func setupFileHandles() throws {
        do {
            readFileHandle = try FileHandle(forUpdating: URL(fileURLWithPath: readFilename))
            writeFileHandle = try FileHandle(forUpdating: URL(fileURLWithPath: writeFilename))
            logger.verbose("local data cache: successfully created file handles")
        } catch {
            logger.error("local data cache: failed to create file handles: \(error.localizedDescription)")
            throw DualFileCacheError.fileHandleCreationFailed
        }
    }

    private func countWriteBatches() {
        do {
            guard let writeHandle = writeFileHandle else {
                logger.error("Cannot count write batches: write file handle is nil")
                return
            }

            try writeHandle.seek(toOffset: 0)
            let writeData = try Data(contentsOf: URL(fileURLWithPath: writeFilename))
            let writeContent = String(data: writeData, encoding: .utf8) ?? ""
            let lines = writeContent.components(separatedBy: eolChar)

            // Each batch is two lines (URL and body)
            numberOfWriteBatches = lines.count / 2

            logger.verbose("Counted \(numberOfWriteBatches) batches in write file")
        } catch {
            logger.error("Failed to count write batches: \(error.localizedDescription)")
            numberOfWriteBatches = 0
        }
    }

    private func initializeReadLineLengths() {
        do {
            guard let readHandle = readFileHandle else {
                logger.error("Cannot initialize read line lengths: read file handle is nil")
                return
            }

            // Reset the array and total
            readLineLengths.removeAll()
            readLineLengthTotal = 0

            // Read the entire file
            try readHandle.seek(toOffset: 0)
            let readData = try Data(contentsOf: URL(fileURLWithPath: readFilename))
            let readContent = String(data: readData, encoding: .utf8) ?? ""
            let lines = readContent.components(separatedBy: eolChar)

            // Store the length of each line
            for line in lines where !line.isEmpty {
                readLineLengths.append(line.count)
                readLineLengthTotal += line.count + eolChar.count
            }

            logger.verbose("Initialized read line lengths. Lines: \(readLineLengths.count), Total chars: \(readLineLengthTotal)")
        } catch {
            logger.error("Failed to initialize read line lengths: \(error.localizedDescription)")
            readLineLengths.removeAll()
            readLineLengthTotal = 0
        }
    }

    private func updateCurrentCacheSize() {
        do {
            let readAttributes = try FileManager.default.attributesOfItem(atPath: readFilename)
            let writeAttributes = try FileManager.default.attributesOfItem(atPath: writeFilename)

            let readSize = readAttributes[.size] as? UInt64 ?? 0
            let writeSize = writeAttributes[.size] as? UInt64 ?? 0

            currentCacheSize = readSize + writeSize
            logger.verbose("Updated cache size: \(currentCacheSize) bytes")
        } catch {
            logger.warning("Failed to get file attributes: \(error.localizedDescription)")
            // If we can't get the file size, assume it's using half the max capacity
            currentCacheSize = maxCacheSize / 2
        }
    }

    /// Merges content from write file into read file, then clears the write file
    private func mergeDataFiles() {
        guard let writeHandle = writeFileHandle, let readHandle = readFileHandle, !isClosed else {
            logger.error("Cannot merge files: handles are closed or nil")
            return
        }

        do {
            // Read from write file
            try writeHandle.seek(toOffset: 0)
            let writeData = writeHandle.readDataToEndOfFile()
            let writeContent = String(data: writeData, encoding: .utf8) ?? ""

            if writeContent.isEmpty {
                logger.info("No content in write file to merge")
                return
            }

            // Append to read file
            try readHandle.seek(toOffset: readHandle.seekToEnd())
            readHandle.write(writeData)

            // Clear write file
            try writeHandle.seek(toOffset: 0)
            try writeHandle.truncate(atOffset: 0)

            // Reset write batches count
            numberOfWriteBatches = 0

            logger.info("Merged \(writeData.count) bytes from write file to read file")

            // Reinitialize read line lengths
            initializeReadLineLengths()

            // Update cache size
            updateCurrentCacheSize()
        } catch {
            logger.error("Failed to merge data files: \(error.localizedDescription)")
        }
    }

    // MARK: - CacheProtocol Implementation

    public func numberOfBatches() -> Int {
        do {
            guard let readHandle = readFileHandle, !isClosed else {
                logger.error("Cannot count batches: read file handle is nil or closed")
                return 0
            }

            // Save current position
            let currentPosition = readHandle.offsetInFile

            // Count lines in read file
            try readHandle.seek(toOffset: 0)
            let content = try String(contentsOfFile: readFilename, encoding: .utf8)
            let lineCount = content.components(separatedBy: eolChar).filter { !$0.isEmpty }.count

            // Restore position
            try readHandle.seek(toOffset: currentPosition)

            // Each batch is a pair of lines (URL + body)
            return lineCount / 2
        } catch {
            logger.error("Failed to count batches: \(error.localizedDescription)")
            return 0
        }
    }

    public func hasContent() -> Bool {
        // First check if cache is closed
        if isClosed {
            logger.error("Cannot check for content: cache is closed")
            return false
        }

        do {
            // Check if read file has content
            let readAttributes = try FileManager.default.attributesOfItem(atPath: readFilename)
            let readSize = readAttributes[.size] as? UInt64 ?? 0

            if readSize > 0 {
                return true
            }

            // If read file is empty but write file has content, merge files
            if numberOfWriteBatches > 0 {
                logger.info("Read file empty but write file has content. Merging files.")
                // Check if we have valid file handles for merging
                guard readFileHandle != nil, writeFileHandle != nil else {
                    logger.error("Cannot merge files: file handles are nil")
                    return false
                }

                mergeDataFiles()

                // Check again if read file now has content
                let newReadAttributes = try FileManager.default.attributesOfItem(atPath: readFilename)
                let newReadSize = newReadAttributes[.size] as? UInt64 ?? 0
                return newReadSize > 0
            }

            return false
        } catch {
            logger.error("Failed to check if cache has content: \(error.localizedDescription)")
            return false
        }
    }

    public func peekContent(destination: inout String, body: inout String) -> Bool {
        guard let readHandle = readFileHandle, !isClosed else {
            logger.error("Cannot peek content: read file handle is nil or closed")
            return false
        }

        // Check if read file has content
        if hasContent() {
            if readLineLengths.count >= 2 {
                do {
                    // Calculate the offset from the end of the file to read the last two lines
                    let bodyLength = readLineLengths[readLineLengths.count - 1]
                    let urlLength = readLineLengths[readLineLengths.count - 2]
                    let offset = bodyLength + urlLength + (eolChar.count * 2)

                    // Get the file size
                    let fileSize = try readHandle.seekToEnd()

                    // Seek to position to read the last URL and body
                    try readHandle.seek(toOffset: fileSize - UInt64(offset))

                    // Read the last two lines
                    let lastLinesData = readHandle.readDataToEndOfFile()
                    let lastLinesString = String(data: lastLinesData, encoding: .utf8) ?? ""
                    let lastLines = lastLinesString.components(separatedBy: eolChar)

                    if lastLines.count >= 2 {
                        // Extract URL and body
                        destination = lastLines[0]
                        body = lastLines[1]

                        if !destination.isEmpty && !body.isEmpty {
                            logger.verbose("Successfully peeked content: \(destination)")
                            return true
                        }
                    }
                } catch {
                    logger.error("Error while peeking content: \(error.localizedDescription)")
                    return false
                }
            }
        } else if numberOfWriteBatches > 0 {
            // Try to merge and then peek again
            mergeDataFiles()
            return peekContent(destination: &destination, body: &body)
        }

        return false
    }

    public func writeContent(destination: String, body: String) -> Bool {
        // Check if cache is closed
        if isClosed {
            logger.error("Cannot write content: cache is closed")
            return false
        }

        // Check size limits
        if !canWrite(destination: destination, body: body) {
            logger.warning("Cannot write content: exceeds size limit")
            return false
        }

        guard let writeHandle = writeFileHandle else {
            logger.error("Cannot write content: write file handle is nil")
            return false
        }

        do {
            // Format the content with newlines
            let content = destination + eolChar + body + eolChar

            // Seek to the end of the file and write
            try writeHandle.seek(toOffset: writeHandle.seekToEnd())

            guard let data = content.data(using: .utf8) else {
                logger.error("Failed to convert content to data")
                return false
            }

            writeHandle.write(data)

            // Increment the batch counter
            numberOfWriteBatches += 1

            // Update cache size
            currentCacheSize += UInt64(data.count)

            logger.verbose("Successfully wrote content to file: \(destination)")
            return true
        } catch {
            logger.error("Error writing content: \(error.localizedDescription)")
            return false
        }
    }

    public func writeContent(_ content: String) -> Bool {
        // Check if cache is closed
        if isClosed {
            logger.error("Cannot write raw content: cache is closed")
            return false
        }

        // Check size limits
        if !canWrite(content) {
            logger.warning("Cannot write raw content: exceeds size limit")
            return false
        }

        guard let writeHandle = writeFileHandle else {
            logger.error("Cannot write raw content: write file handle is nil")
            return false
        }

        do {
            // Format the raw content with newline
            let formattedContent = content + eolChar

            // Seek to the end of the file and write
            try writeHandle.seek(toOffset: writeHandle.seekToEnd())

            guard let data = formattedContent.data(using: .utf8) else {
                logger.error("Failed to convert raw content to data")
                return false
            }

            writeHandle.write(data)

            // Increment the batch counter
            numberOfWriteBatches += 1

            // Update cache size
            currentCacheSize += UInt64(data.count)

            logger.verbose("Successfully wrote raw content to file")
            return true
        } catch {
            logger.error("Error writing raw content: \(error.localizedDescription)")
            return false
        }
    }

    public func popContent() {
        guard let readHandle = readFileHandle, !isClosed else {
            logger.error("Cannot pop content: file handle is closed or nil")
            return
        }

        // Check if there's anything to pop
        if readLineLengths.count < 2 {
            logger.warning("No content to pop")
            return
        }

        do {
            // Get the lengths of the last two lines (body and URL)
            let bodyLength = readLineLengths.removeLast()
            let urlLength = readLineLengths.removeLast()

            // Calculate the number of bytes to remove (including newlines)
            let bytesToRemove = bodyLength + urlLength + (eolChar.count * 2)
            readLineLengthTotal -= bytesToRemove

            // Truncate the file
            try readHandle.truncate(atOffset: UInt64(readLineLengthTotal))

            logger.verbose("Successfully popped content. Removed \(bytesToRemove) bytes")

            // Update cache size
            updateCurrentCacheSize()
        } catch {
            logger.error("Error popping content: \(error.localizedDescription)")
        }
    }

    public func close() {
        do {
            try readFileHandle?.close()
            try writeFileHandle?.close()
            logger.info("Closed file handles")
        } catch {
            logger.error("Error closing file handles: \(error.localizedDescription)")
        }

        readFileHandle = nil
        writeFileHandle = nil

        // Mark as closed to prevent further writes
        isClosed = true
    }

    public func canWrite(destination: String, body: String) -> Bool {
        // Check if cache is closed
        if isClosed {
            return false
        }

        // Calculate size of new entry
        let newEntrySize = destination.utf8.count + body.utf8.count + (eolChar.utf8.count * 2)

        // Check if would exceed max size
        if currentCacheSize + UInt64(newEntrySize) > maxCacheSize {
            if !displayedSizeWarning {
                displayedSizeWarning = true
                logger.warning("Data Cache reached size limit!")
            }
            return false
        }

        displayedSizeWarning = false
        return true
    }

    public func canWrite(_ content: String) -> Bool {
        // Check if cache is closed
        if isClosed {
            return false
        }

        // Calculate size of new entry
        let newEntrySize = content.utf8.count + eolChar.utf8.count

        // Check if would exceed max size
        if currentCacheSize + UInt64(newEntrySize) > maxCacheSize {
            if !displayedSizeWarning {
                displayedSizeWarning = true
                logger.warning("Data Cache reached size limit!")
            }
            return false
        }

        displayedSizeWarning = false
        return true
    }

    public func getCacheFillAmount() -> Float {
        updateCurrentCacheSize()

        if maxCacheSize <= 0 {
            return 1.0
        }

        return Float(currentCacheSize) / Float(maxCacheSize)
    }
}
