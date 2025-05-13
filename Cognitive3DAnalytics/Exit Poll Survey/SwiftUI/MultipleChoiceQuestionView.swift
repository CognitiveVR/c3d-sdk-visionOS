//
//  MultipleChoiceQuestionView.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-01-05.
//

import SwiftUI

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

#Preview("2 Choices - Dynamic Binding") {
    struct PreviewWrapper: View {
        @State private var selectedAnswer: String? = nil

        var body: some View {
            MultipleChoiceQuestionView(
                selectedAnswer: $selectedAnswer,
                title: "Multiple Choice Question",
                answers: ["Choice 1", "Choice 2"]
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray)
                    .shadow(radius: 5)
            )
            .frame(width: 400, height: 600)
        }
    }

    return PreviewWrapper()
}

#Preview("3 Choices") {
    struct PreviewWrapper: View {
        @State private var selectedAnswer: String? = nil

        var body: some View {
            MultipleChoiceQuestionView(
                selectedAnswer: $selectedAnswer,
                title: "Multiple Choice Question - 3 options",
                answers: ["Choice 1", "Choice 2", "Choice 3"]
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray)
                    .shadow(radius: 5)
            )
            .frame(width: 400, height: 600)
        }
    }

    return PreviewWrapper()
}

#Preview("4 Choices") {
    struct PreviewWrapper: View {
        @State private var selectedAnswer: String? = nil

        var body: some View {
            MultipleChoiceQuestionView(
                selectedAnswer: $selectedAnswer,
                title: "Multiple Choice Question - 4 options",
                answers: ["Choice 1", "Choice 2", "Choice 3", "Choice 4"]
            )
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray)
                    .shadow(radius: 5)
            )
            .frame(width: 400, height: 600)
        }
    }

    return PreviewWrapper()
}
