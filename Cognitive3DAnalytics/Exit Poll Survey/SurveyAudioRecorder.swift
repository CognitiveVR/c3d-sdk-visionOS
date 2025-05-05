//
//  SurveyAudioRecorder.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import AVFoundation
import Combine
import SwiftUI

/// Errors that can occur during audio recording
enum AudioRecordingError: Error, LocalizedError {
    case permissionDenied
    case deviceUnavailable
    case recordingFailed(String)
    case playbackFailed(String)
    case encodingFailed(String)
    case emptyRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access is required for recording"
        case .deviceUnavailable:
            return "Audio recording device is unavailable"
        case .recordingFailed(let reason):
            return "Recording failed: \(reason)"
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
        case .encodingFailed(let reason):
            return "Could not process audio: \(reason)"
        case .emptyRecording:
            return "The recording is empty"
        }
    }
}

/// Model representing a single recording
struct Recording: Identifiable {
    let id: String
    let fileURL: URL?
    let createdAt: Date
    let duration: TimeInterval?

    // Format duration as string (MM:SS)
    var formattedDuration: String {
        let duration = self.duration ?? 0
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // Format created date as string
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}

// Format time interval as string (MM:SS)
extension TimeInterval {
    var formattedString: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let tenths = Int((self * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}

/// The `SurveyAudioRecorder` is a class for audio recording;  it is used by exit poll surverys for recording a voice response to a  question in a question set.
/// The data is internally represented using  linear PCM often referred to as the WAV format.
/// [Wav format](https://en.wikipedia.org/wiki/WAV)
class SurveyAudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    // Published properties that the UI can observe
    @Published var recordings: [Recording] = []
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isPlaying = false

    // Error handling properties
    @Published var recordingError: AudioRecordingError?
    @Published var showErrorAlert = false

    // Private properties
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var audioSession: AVAudioSession
    private var cancellables = Set<AnyCancellable>()
    private var currentQuestionIndex: Int?

    // Directory for storing recordings
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // The current recording file URL
    private var currentRecordingURL: URL?

    private var core: Cognitive3DAnalyticsCore

    init(core: Cognitive3DAnalyticsCore) {
        self.audioSession = AVAudioSession.sharedInstance()
        self.core = core
        super.init()

        // Load previously saved recordings
        Task {
            await fetchRecordings()
        }
    }

    // Report an error and show alert
    @MainActor
    func reportError(_ error: AudioRecordingError) {
        self.recordingError = error
        self.showErrorAlert = true
    }

    // Clear error state
    @MainActor
    func clearError() {
        self.recordingError = nil
        self.showErrorAlert = false
    }

    // Request permission to record audio
    func requestPermission() async -> Bool {
        do {
            // Configure audio session
            try audioSession.setCategory(
                .playAndRecord,
                options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Check if recording is available
            if !audioSession.isInputAvailable {
                core.logger?.info("Audio input is not available on this device")
                await reportError(.deviceUnavailable)
                return false
            }

            // Request permission
#if os(visionOS)
            // visionOS approach
            let granted = await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                await reportError(.permissionDenied)
            }
            return granted
#else
            // iOS/iPadOS approach
            let granted = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                reportError(.permissionDenied)
            }
            return granted
#endif
        } catch {
            core.logger?.error("Failed to set up audio session: \(error.localizedDescription)")
            await reportError(.recordingFailed("Failed to set up audio session: \(error.localizedDescription)"))
            return false
        }
    }

    // Start recording audio
    func startRecording() async {
        // Clear any previous errors
        await clearError()

        let granted = await requestPermission()
        guard granted else {
            // Error already reported in requestPermission
            return
        }

        // Configure audio session again to ensure it's properly set
        do {
            try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            core.logger?.error("Error configuring audio session: \(error)")
            await reportError(.recordingFailed("Failed to configure audio session: \(error.localizedDescription)"))
            return
        }

        let recordingName = UUID().uuidString
        let audioFilename = documentsDirectory.appendingPathComponent("\(recordingName).wav")
        currentRecordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,  // Mono for smaller file size
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self

            // Prepare to record
            let prepareSuccess = audioRecorder?.prepareToRecord() ?? false
            if !prepareSuccess {
                await reportError(.recordingFailed("Failed to prepare recorder"))
                return
            }

            // Start recording
            let recordSuccess = audioRecorder?.record() ?? false
            if !recordSuccess {
                await reportError(.recordingFailed("Failed to start recording"))
                return
            }

            await MainActor.run {
                isRecording = true
                recordingTime = 0
                startTimer()
            }
            // Notify listeners
            NotificationCenter.default.post(name: Notification.Name("OnMicrophoneRecordingBegin"), object: nil)
        } catch {
            core.logger?.error("Could not start recording: \(error.localizedDescription)")
            await reportError(.recordingFailed(error.localizedDescription))
        }
    }

    // Start recording audio for a specific question index
    func startRecording(forQuestionIndex index: Int) async {
        currentQuestionIndex = index
        await startRecording()
    }

    // Directly save the recording information after stopping
    @MainActor
    func saveRecordingInfo() {
        guard let url = currentRecordingURL else {
            core.logger?.warning("No active recording URL")
            return
        }

        // Make sure file exists and is not empty
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            core.logger?.warning("Recording file does not exist at path: \(url.path)")
            return
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            if fileSize == 0 {
                core.logger?.warning("Warning: Recording file is empty (0 bytes)")
                return
            }

            let createdAt = Date()

            // Use recording time as duration since we already have it
            let duration = self.recordingTime

            // Create recording object
            let recordingId = url.deletingPathExtension().lastPathComponent
            let newRecording = Recording(id: recordingId, fileURL: url, createdAt: createdAt, duration: duration)

            // Add to recordings array immediately
            if self.recordings.isEmpty {
                self.recordings = [newRecording]
            } else {
                self.recordings.insert(newRecording, at: 0)
            }
            core.logger?.info("Recording saved: \(url.path) with duration: \(duration)s")
        } catch {
            core.logger?.error("Error accessing recording file: \(error.localizedDescription)")
        }
    }

    // Stop recording audio
    @MainActor
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil

        // Immediately save the recording info
        saveRecordingInfo()

        // Still do the fetch for completeness
        Task {
            await fetchRecordings()
        }

        // Notify listeners
        NotificationCenter.default.post(name: Notification.Name("OnMicrophoneRecordingStopped"), object: nil)
    }

    // Start a timer to track recording duration
    private func startTimer() {
        timer?.invalidate()
        timer = nil

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // Use MainActor.run explicitly for UI updates
            Task { @MainActor in
                self.recordingTime += 0.1
            }
        }

        // Make sure timer runs even during scrolling or user interaction
        if let activeTimer = timer {
            RunLoop.current.add(activeTimer, forMode: .common)
        }
    }

    // Get the duration of an audio file asynchronously
    private func getAudioDuration(for url: URL) async -> TimeInterval? {
        // Make sure the file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            core.logger?.error("File does not exist at path: \(url.path)")
            return nil
        }

        // Get file size to check if it's empty
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            if fileSize == 0 {
                core.logger?.warning("File is empty (0 bytes)")
                return nil
            }
        } catch {
            core.logger?.error("Error checking file size: \(error)")
        }

        // Create audio asset and get duration asynchronously
        let asset = AVURLAsset(url: url)
        do {
            let durationValue = try await asset.load(.duration)
            let duration = durationValue.seconds

            if duration > 0 {
                return duration
            } else {
                // Fallback for duration
                core.logger?.warning("Duration reported as zero, using estimate")
                return 1.0  // Default fallback duration
            }
        } catch {
            core.logger?.error("Error loading asset duration: \(error)")
            return 1.0  // Default fallback duration
        }
    }

    // Load saved recordings from the documents directory
    private func fetchRecordings() async {
        do {
            let fileManager = FileManager.default
            let urls = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)

            // Filter for audio files only
            let audioFiles = urls.filter { $0.pathExtension == "wav" }

            // Process files and gather recordings using a structured approach
            let processedRecordings = await withTaskGroup(of: Recording?.self) { group in
                for url in audioFiles {
                    group.addTask {
                        // Each task processes one file independently
                        let fileName = url.deletingPathExtension().lastPathComponent
                        let createdAt = (try? fileManager.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date()

                        // Get duration
                        if let duration = await self.getAudioDuration(for: url) {
                            return Recording(id: fileName, fileURL: url, createdAt: createdAt, duration: duration)
                        }
                        return nil
                    }
                }

                // Collect results
                var results = [Recording]()
                for await recording in group {
                    if let recording = recording {
                        results.append(recording)
                    }
                }

                // Sort by creation date (newest first)
                return results.sorted(by: { $0.createdAt > $1.createdAt })
            }

            // Update on main actor
            await MainActor.run {
                self.recordings = processedRecordings
            }

        } catch {
            core.logger?.error("Error fetching recordings: \(error.localizedDescription)")
            await MainActor.run {
                reportError(.recordingFailed("Error accessing saved recordings: \(error.localizedDescription)"))
            }
        }
    }

    // Delete a recording
    @MainActor func deleteRecording(id: String) {
        guard let index = recordings.firstIndex(where: { $0.id == id }),
              let url = recordings[index].fileURL
        else {
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
            self.recordings.remove(at: index)
        } catch {
            core.logger?.error("Error deleting recording: \(error.localizedDescription)")
            reportError(.recordingFailed("Error deleting recording: \(error.localizedDescription)"))
        }
    }

    // Play a recording
    @MainActor
    func playRecording(url: URL) {
        clearError()

        do {
            // Stop any existing playback
            stopPlayback()

            // Configure audio session for playback
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            // Create and prepare player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            // Start playback
            let playbackStarted = audioPlayer?.play() ?? false
            if playbackStarted {
                isPlaying = true
                core.logger?.info("Playback started")
            } else {
                reportError(.playbackFailed("Failed to start playback"))
            }
        } catch {
            core.logger?.error("Error playing recording: \(error.localizedDescription)")
            reportError(.playbackFailed(error.localizedDescription))
        }
    }

    // Stop any current playback
    @MainActor
    func stopPlayback() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        audioPlayer = nil
        isPlaying = false
    }

    // Get base64 encoded string of a recording for uploading
    @MainActor func getBase64EncodedAudio(for recording: Recording) -> String? {
        guard let filePath = recording.fileURL else {
            reportError(.recordingFailed("Recording file not found"))
            return nil
        }
        return getBase64EncodedAudioFromURL(filePath)
    }

    // Get base64 encoded string from a file URL
    @MainActor
    func getBase64EncodedAudioFromURL(_ url: URL) -> String? {
        do {
            core.logger?.info("Attempting to read audio data from: \(url.path)")

            // First check if file exists
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: url.path) else {
                core.logger?.info("File does not exist at: \(url.path)")
                reportError(.recordingFailed("Audio file not found"))
                return nil
            }

            // Get file attributes
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? UInt64 ?? 0
            core.logger?.info("Audio file size: \(fileSize) bytes")

            if fileSize == 0 {
                core.logger?.warning("Warning: Audio file is empty (0 bytes)")
                reportError(.emptyRecording)
                return nil
            }

            // Read the data
            let audioData = try Data(contentsOf: url)
            if audioData.isEmpty {
                core.logger?.warning("Warning: Audio data is empty after reading")
                reportError(.emptyRecording)
                return nil
            }

            core.logger?.verbose("Successfully read audio data: \(audioData.count) bytes")
            let base64String = audioData.base64EncodedString()
            core.logger?.verbose("Base64 encoded string length: \(base64String.count)")

            return base64String
        } catch {
            core.logger?.error("Failed to encode audio file: \(error.localizedDescription)")
            reportError(.encodingFailed(error.localizedDescription))
            return nil
        }
    }

    // Get the last recording as base64 encoded string
    @MainActor func getLastRecordingAsBase64() -> String? {
        // First check if we have a current recording URL that we can use directly
        if let currentURL = currentRecordingURL, FileManager.default.fileExists(atPath: currentURL.path) {
            core.logger?.verbose("Using current recording URL for base64 encoding: \(currentURL.path)")
            return getBase64EncodedAudioFromURL(currentURL)
        }

        // Fall back to the recordings array
        guard !recordings.isEmpty else {
            core.logger?.warning("No recordings available in array")
            reportError(.recordingFailed("No recordings available"))
            return nil
        }

        core.logger?.verbose("Using recording from array for base64 encoding: \(String(describing: recordings.first?.fileURL?.path))")
        return getBase64EncodedAudio(for: recordings[0])
    }

    // MARK: - Delegate Methods

    // AVAudioRecorderDelegate method called when recording finishes
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        core.logger?.info("Recording finished, success: \(flag)")

        if flag {
            Task {
                await fetchRecordings()
            }
        } else {
            core.logger?.error("Recording failed")
            Task { @MainActor in
                reportError(.recordingFailed("Recording was not completed successfully"))
                isRecording = false
            }
        }
    }

    // AVAudioRecorderDelegate method for encoding errors
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        core.logger?.error("Recording encode error: \(String(describing: error))")

        Task { @MainActor in
            if let error = error {
                reportError(.encodingFailed(error.localizedDescription))
            } else {
                reportError(.encodingFailed("Unknown encoding error occurred"))
            }
            isRecording = false
        }
    }

    // AVAudioPlayerDelegate method called when playback finishes
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        core.logger?.info("Playback finished, success: \(flag)")

        Task { @MainActor in
            if !flag {
                reportError(.playbackFailed("Playback did not complete successfully"))
            }
            isPlaying = false
        }

        // Reset audio session if needed
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            core.logger?.error("Error deactivating audio session: \(error)")
        }
    }

    // AVAudioPlayerDelegate method for decoding errors
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        core.logger?.error("Playback decode error: \(String(describing: error))")

        Task { @MainActor in
            if let error = error {
                reportError(.playbackFailed("Error during playback: \(error.localizedDescription)"))
            } else {
                reportError(.playbackFailed("Unknown playback error occurred"))
            }
            isPlaying = false
        }
    }
}
