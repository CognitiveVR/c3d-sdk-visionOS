//
//  VoiceQuestionView.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2025 Cognitive3D, Inc. All rights reserved.
//

import AVFoundation
import SwiftUI

/// A view that presents a voice recording question for exit polls
/// This class uses AVFoundation to record the audio. The data is encoded as base 64 before uploading to the C3D back end.
public struct VoiceQuestionView: View {
    @EnvironmentObject var viewModel: ExitPollSurveyViewModel
    @StateObject private var audioRecorder = SurveyAudioRecorder(core: Cognitive3DAnalyticsCore.shared)
    @State private var recordingCompleted = false
    @State private var showingPermissionAlert = false
    @State private var isPlaying = false

    // Time limit for the recording
    private let recordingTimeLimit: TimeInterval

    // Binding to enable the confirm button in parent view
    @Binding public var isConfirmButtonEnabled: Bool

    // Question properties
    public let questionIndex: Int
    public let title: String

    // Public initializer
    public init(
        isConfirmButtonEnabled: Binding<Bool>, questionIndex: Int, title: String,
        recordingTimeLimit: TimeInterval = 10.0
    ) {
        self._isConfirmButtonEnabled = isConfirmButtonEnabled
        self.questionIndex = questionIndex
        self.title = title
        self.recordingTimeLimit = recordingTimeLimit
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if recordingCompleted {
                // Recording completed view
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 70))
                        .foregroundColor(.green)

                    Text("Voice Recording Completed")
                        .font(.title3)
                        .fontWeight(.medium)

                    HStack(spacing: 20) {
                        // Play recording button
                        Button(action: {
                            if isPlaying {
                                // Stop playback if already playing
                                audioRecorder.stopPlayback()
                                isPlaying = false
                            } else if let lastRecording = audioRecorder.recordings.first,
                                let url = lastRecording.fileURL
                            {
                                // Start playback
                                audioRecorder.playRecording(url: url)
                                isPlaying = true

                                // Auto-reset playing state after duration
                                if let duration = lastRecording.duration {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                        isPlaying = false
                                    }
                                }
                            }
                        }) {
                            Label(
                                isPlaying ? "Stop" : "Play",
                                systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill"
                            )
                            .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)

                        // Record again button
                        Button(action: {
                            recordingCompleted = false
                            isConfirmButtonEnabled = false

                            // Delete existing recording before recording again
                            if let recordingId = audioRecorder.recordings.first?.id {
                                audioRecorder.deleteRecording(id: recordingId)
                            }
                        }) {
                            Label("Record Again", systemImage: "mic.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            } else {
                // Recording controls
                VStack(spacing: 16) {
                    if audioRecorder.isRecording {
                        // Recording in progress UI
                        Text(audioRecorder.recordingTime.formattedString)
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)

                        // Time remaining indicator
                        ProgressView(
                            value: min(audioRecorder.recordingTime, recordingTimeLimit),
                            total: max(recordingTimeLimit, 0.1)
                        )
                        .progressViewStyle(.linear)
                        .frame(width: 240)
                        .padding(.vertical)

                        Text("Time Remaining: \((recordingTimeLimit - audioRecorder.recordingTime).formattedString)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                            // Auto-stop recording when time limit is reached
                            .onChange(of: audioRecorder.recordingTime) { _, newValue in
                                if newValue >= recordingTimeLimit {
                                    stopRecording()

                                    // Notify time's up
                                    NotificationCenter.default.post(
                                        name: Notification.Name("OnMicrophoneRecordingTimeUp"), object: nil)
                                }
                            }
                    } else {
                        // Instructions before recording
                        Text("Tap the button below to start recording your answer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Maximum recording time: \(recordingTimeLimit.formattedString)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Record/Stop button
                    Button(action: {
                        if audioRecorder.isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(audioRecorder.isRecording ? Color.red.opacity(0.8) : Color.red)
                                .frame(width: 80, height: 80)

                            if audioRecorder.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            } else {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .accessibilityLabel(audioRecorder.isRecording ? "Stop recording" : "Start recording")
                    .padding()
                }
            }
        }
        .padding(.vertical)
        .alert("Microphone Access", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("Please allow microphone access in Settings to record audio.")
        }
        // Error alert
        .alert(
            "Recording Error",
            isPresented: $audioRecorder.showErrorAlert,
            presenting: audioRecorder.recordingError
        ) { _ in
            Button("OK") {
                audioRecorder.clearError()
            }
        } message: { error in
            Text(error.errorDescription ?? "An unknown error occurred")
        }
        // Clean up when view disappears
        .onDisappear {
            cleanupRecordings()
        }
    }

    // Function to start recording
    private func startRecording() {
        // Clear any existing recordings first
        cleanupRecordings()

        Task {
            let granted = await audioRecorder.requestPermission()
            if granted {
                await audioRecorder.startRecording(forQuestionIndex: questionIndex)
            } else {
                showingPermissionAlert = true
            }
        }
    }

    // Function to stop recording and process the result
    private func stopRecording() {
        // First stop the recording to create the file
        audioRecorder.stopRecording()

        // Add a small delay to ensure file is fully written
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            // Save recording info immediately without waiting for fetch
            self.audioRecorder.saveRecordingInfo()

            // Get the base64 encoding and update the view model
            if let base64Audio = self.audioRecorder.getLastRecordingAsBase64() {
                print("Successfully obtained base64 audio data")

                // Update the ExitPollSurveyViewModel with the voice recording
                self.viewModel.updateMicrophoneAnswer(for: self.questionIndex, with: base64Audio)
                self.recordingCompleted = true
                self.isConfirmButtonEnabled = true  // Enable the confirm button in parent view
            } else {
                // Handle the case where we couldn't get the base64 audio
                print("Failed to obtain base64 audio data")

                // Try again after another short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                    if let base64Audio = self.audioRecorder.getLastRecordingAsBase64() {
                        print("Second attempt succeeded in getting base64 audio")
                        self.viewModel.updateMicrophoneAnswer(for: self.questionIndex, with: base64Audio)
                        self.recordingCompleted = true
                        self.isConfirmButtonEnabled = true
                    } else {
                        print("Second attempt also failed to get base64 audio")
                    }
                }
            }
        }
    }

    // Function to clean up all recordings when leaving the view
    private func cleanupRecordings() {
        // Stop any ongoing recording or playback
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        }

        // Stop any ongoing playback
        audioRecorder.stopPlayback()
        isPlaying = false

        // Only keep the recording if it's completed and the answer is set
        if !recordingCompleted {
            // Delete all recordings except the one we want to keep
            for recording in audioRecorder.recordings {
                audioRecorder.deleteRecording(id: recording.id)
            }
        }
    }
}
