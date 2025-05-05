//
//  ScaleQuestionView.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-01-05.
//

import SwiftUI

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


#Preview {
    ScaleQuestionView(
        answer: .constant(5), title: "How likely are you to recommend this app?", min: 0, max: 10,
        minLabel: "Not likely", maxLabel: "Very likely"
    )
    .background(
        RoundedRectangle(cornerRadius: 20)  // Specify corner radius
            .fill(Color.gray)  // Specify background color
            .shadow(radius: 5)  // Optional: Add shadow for a polished look
    )
    .frame(width: 400, height: 600)
}
