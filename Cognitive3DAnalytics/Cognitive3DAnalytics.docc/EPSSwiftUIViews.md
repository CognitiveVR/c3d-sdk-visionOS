# SwiftUI Views for Exit Poll Surveys

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

## Overview

We provide SwiftUI views for each of the question types that can be in an exit poll survey.  You can create your own custom classes using these SwiftUI views as reference.

## Boolean Question

```swift
/// View for presenting a boolean question with "True" and "False" buttons.
public struct BooleanQuestionView: View {
    @Binding public var answer: Bool?  // Binding to the answer state (nil = no selection)
    public let title: String  // Title of the question

    /// Initializes the `BooleanQuestionView` with the answer binding and title.
    /// - Parameters:
    ///   - answer: A binding to the boolean answer value, or nil for no selection.
    ///   - title: The title of the question.
    public init(answer: Binding<Bool?>, title: String) {
        self._answer = answer
        self.title = title
    }

    public var body: some View {
        VStack {
            // Display the question title
            Text(title)
                .font(.headline)
                .padding(.top)

            // Buttons for "True" and "False"
            HStack {
                Button(action: { answer = true }) {
                    Text("True")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(answer == true ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(answer == true ? Color.blue : Color.clear, lineWidth: answer == true ? 4 : 0)
                        )
                }
                Button(action: { answer = false }) {
                    Text("False")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(answer == false ? Color.red : Color.gray.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(answer == false ? Color.red : Color.clear, lineWidth: answer == false ? 4 : 0)
                        )
                }
            }
            .padding()
        }
    }
}

```

## Happy/Sad Question

```swift
/// View for presenting a happy/sad question.
public struct HappySadQuestionView: View {
    @Binding public var answer: Bool?  // Binding to the answer state (nil = no selection)
    public let title: String  // Title of the question

    /// Initializes the `HappySadQuestionView` with the answer binding and title.
    /// - Parameters:
    ///   - answer: A binding to the boolean answer value, or nil for no selection.
    ///   - title: The title of the question.
    public init(answer: Binding<Bool?>, title: String) {
        self._answer = answer
        self.title = title
    }

    public var body: some View {
        VStack {
            // Display the question title
            Text(title)
                .font(.headline)
                .padding(.top)

            // Buttons for "Happy" and "Sad" faces
            HStack {
                Button(action: { answer = true }) {
                    Text("😊").font(.largeTitle)
                        .overlay(
                            Circle()
                                .stroke(answer == true ? Color.green : Color.clear, lineWidth: answer == true ? 4 : 0)
                        )
                }
                Button(action: { answer = false }) {
                    Text("😢").font(.largeTitle)
                        .overlay(
                            Circle()
                                .stroke(answer == false ? Color.red : Color.clear, lineWidth: answer == false ? 4 : 0)
                        )
                }
            }
            .padding()
        }
    }
}

```

## Thumbs Up/Thumbs Down Question

```swift
/// View for presenting a thumbs-up/thumbs-down question.
public struct ThumbsQuestionView: View {
    @Binding public var answer: Bool?  // Binding to the answer state (nil = no selection)
    public let title: String  // Title of the question

    /// Initializes the `ThumbsQuestionView` with the answer binding and title.
    /// - Parameters:
    ///   - answer: A binding to the boolean answer value, or nil for no selection.
    ///   - title: The title of the question.
    public init(answer: Binding<Bool?>, title: String) {
        self._answer = answer
        self.title = title
    }

    public var body: some View {
        VStack {
            // Display the question title
            Text(title)
                .font(.headline)
                .padding(.top)

            // Buttons for "Thumbs Up" and "Thumbs Down"
            HStack {
                Button(action: { answer = true }) {
                    Text("👍").font(.largeTitle)
                        .overlay(
                            Circle()
                                .stroke(answer == true ? Color.green : Color.clear, lineWidth: answer == true ? 4 : 0)
                        )
                }
                Button(action: { answer = false }) {
                    Text("👎").font(.largeTitle)
                        .overlay(
                            Circle()
                                .stroke(answer == false ? Color.red : Color.clear, lineWidth: answer == false ? 4 : 0)
                        )
                }
            }
            .padding()
        }
    }
}

```

## Multiple Choice Question

```swift
/// View for presenting a multiple-choice question as a list of buttons.
public struct MultipleChoiceQuestionView: View {
    @Binding public var selectedAnswer: String?  // Binding to the selected answer (optional)
    public let title: String  // Title of the question
    public let answers: [String]  // List of possible answers
    private var shouldDisplayClearButton = false

    /// Initializes the `MultipleChoiceQuestionView` with the answer binding, title, and answers.
    /// - Parameters:
    ///   - selectedAnswer: A binding to the selected answer.
    ///   - title: The title of the question.
    ///   - answers: The list of possible answers.
    public init(selectedAnswer: Binding<String?>, title: String, answers: [String]) {
        self._selectedAnswer = selectedAnswer
        self.title = title
        self.answers = answers
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Display the question title
            Text(title)
                .font(.headline)
                .padding(.bottom)

            // Render answers as a list of buttons
            ForEach(answers, id: \.self) { answer in
                Button(action: {
                    selectedAnswer = answer
                }) {
                    Text(answer)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(selectedAnswer == answer ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedAnswer == answer ? .white : .black)
                        .cornerRadius(8)
                }
            }

            // Add a "Clear Selection" button if an answer is selected
            if shouldDisplayClearButton && selectedAnswer != nil {
                Button("Clear Selection") {
                    selectedAnswer = nil
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
                .background(Color.red.opacity(0.2))
                .foregroundColor(.red)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

```

## Scale Question

```swift
/// A view for presenting a scale question with a slider.
/// Displays min and max numeric values along with corresponding labels.
public struct ScaleQuestionView: View {
    @Binding public var answer: Int  // Binding to the slider value
    public let title: String  // Title of the question
    public let min: Int  // Minimum value for the slider
    public let max: Int  // Maximum value for the slider
    public let minLabel: String  // Label for the minimum value
    public let maxLabel: String  // Label for the maximum value

    /// Initializes the `ScaleQuestionView` with the answer binding, title, and range details.
    /// - Parameters:
    ///   - answer: A binding to the current value of the slider.
    ///   - title: The title of the question to be displayed.
    ///   - min: The minimum numeric value of the slider.
    ///   - max: The maximum numeric value of the slider.
    ///   - minLabel: A descriptive label for the minimum value.
    ///   - maxLabel: A descriptive label for the maximum value.
    public init(answer: Binding<Int>, title: String, min: Int, max: Int, minLabel: String, maxLabel: String) {
        self._answer = answer
        self.title = title
        self.min = min
        self.max = max
        self.minLabel = minLabel
        self.maxLabel = maxLabel
    }

    public var body: some View {
        VStack {
            // Title of the question
            Text(title)
                .font(.headline)
                .padding(.bottom)

            // Slider for numeric selection
            Slider(
                value: Binding(
                    get: { Double(answer) },
                    set: { newValue in answer = Int(newValue) }
                ),
                in: Double(min)...Double(max),
                step: 1
            )
            .padding(.horizontal)

            // Min/Max numeric values with descriptive labels
            HStack {
                VStack(alignment: .leading) {
                    Text("\(min)")
                        .font(.subheadline)
                    Text(minLabel)
                        .font(.caption)
                        .foregroundColor(.white)
                }

                // Display the current slider value
                if (answer != noAnswerSet) {
                    Spacer()
                    Text("Current Value: \(answer)")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }

                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(max)")
                        .font(.subheadline)
                    Text(maxLabel)
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)

        }
        .padding()
        .frame(maxWidth: 400)  // Constrain width for consistent layout
        .background(.regularMaterial.opacity(0.85))  // Semi-transparent background
        .cornerRadius(12)  // Rounded corners
        .shadow(radius: 4)  // Subtle shadow for depth
    }
}

```

Voice Question

```swift
/// A view that presents a voice recording question for exit polls
public struct VoiceQuestionView: View {
    @EnvironmentObject var viewModel: ExitPollSurveyViewModel
    @StateObject private var audioRecorder = SurveyAudioRecorder()
    @State private var recordingCompleted = false
    @State private var showingPermissionAlert = false
    @State private var isPlaying = false

    // Time limit for the recording
    @State public var recordingTimeLimit: TimeInterval = 10.0

    // Binding to enable the confirm button in parent view
    @Binding public var isConfirmButtonEnabled: Bool

    // Question properties
    public let questionIndex: Int
    public let title: String

    // Public initializer
    public init(isConfirmButtonEnabled: Binding<Bool>, questionIndex: Int, title: String) {
        self._isConfirmButtonEnabled = isConfirmButtonEnabled
        self.questionIndex = questionIndex
        self.title = title
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
                                    let url = lastRecording.fileURL {
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
                            Label(isPlaying ? "Stop" : "Play",
                                  systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill")
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
                        ProgressView(value: audioRecorder.recordingTime, total: recordingTimeLimit)
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
                                NotificationCenter.default.post(name: Notification.Name("OnMicrophoneRecordingTimeUp"), object: nil)
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
            Button("Cancel", role: .cancel) { }
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
                self.isConfirmButtonEnabled = true // Enable the confirm button in parent view
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
```
