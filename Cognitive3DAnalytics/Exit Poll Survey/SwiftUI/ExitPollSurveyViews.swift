//
//  ExitPollSurveyViews.swift
//  Cognitive3DAnalytics
//

import SwiftUI

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

// Previews for all views
#Preview {
    struct CombinedPreview: View {
        @State private var booleanAnswer: Bool? = nil  // Defaults to no selection
        @State private var happySadAnswer: Bool? = nil  // Defaults to no selection
        @State private var thumbsAnswer: Bool? = nil  // Defaults to no selection

        var body: some View {
            VStack {
                BooleanQuestionView(answer: $booleanAnswer, title: "Is today Sunday?")
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray)
                            .shadow(radius: 5)
                    )
                    .frame(width: 400, height: 200)

                HappySadQuestionView(answer: $happySadAnswer, title: "Are you happy today?")
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray)
                            .shadow(radius: 5)
                    )
                    .frame(width: 400, height: 200)

                ThumbsQuestionView(answer: $thumbsAnswer, title: "Rate your experience today.")
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray)
                            .shadow(radius: 5)
                    )
                    .frame(width: 400, height: 200)
            }
            .padding()
        }
    }

    return CombinedPreview()
}
