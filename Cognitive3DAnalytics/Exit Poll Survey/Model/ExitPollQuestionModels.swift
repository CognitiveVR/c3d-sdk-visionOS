//
//  ExitPollQuestionModels.swift
//  Cognitive3DAnalytics
//
//  This module defines the question types for an exit poll survey
//  and includes hints for presenting each type in a UI, such as SwiftUI.
//

import Foundation

/// Base class for all question types.
/// - Shared property: `title` - the title or prompt for the question.
/// - Shared property: `saveToSession` - whether the answer should be saved to the session.
public class ExitPollQuestion {
    public let title: String
    public let saveToSession: Bool

    public init(title: String, saveToSession: Bool) {
        self.title = title
        self.saveToSession = saveToSession
    }
}

/// BooleanQuestion represents a yes/no question.
/// - Suggested Presentation:
///   - Toggle in SwiftUI: `Toggle(question.title, isOn: $answer)`
///   - Radio buttons for "Yes" and "No".
public class BooleanQuestion: ExitPollQuestion {
    public let presentationType: BooleanPresentationType

    public init(title: String, saveToSession: Bool, presentationType: BooleanPresentationType) {
        self.presentationType = presentationType
        super.init(title: title, saveToSession: saveToSession)
    }
}

/// Defines possible presentation types for BooleanQuestion.
public enum BooleanPresentationType {
    case toggle
    case radioButtons
    case checkbox
}

/// HappySadQuestion represents a question that captures sentiment.
/// - Suggested Presentation:
///   - Emoji-based buttons (😊 and 😢) for "Happy" and "Sad".
///   - Use a VStack with HStack for layout.
public class HappySadQuestion: ExitPollQuestion {}

/// ThumbsQuestion represents a thumbs-up/thumbs-down question.
/// - Suggested Presentation:
///   - Use icons for thumbs-up (👍) and thumbs-down (👎).
///   - SwiftUI example:
///     ```swift
///     HStack {
///         Button("👍") { answer = true }
///         Button("👎") { answer = false }
///     }
///     ```
public class ThumbsQuestion: ExitPollQuestion {}

/// MultipleChoiceQuestion represents a question with a list of possible answers.
/// - Suggested Presentation:
///   - Use a Picker or List in SwiftUI.
///   - SwiftUI example:
///     ```swift
///     Picker(selection: $selectedAnswer, label: Text(question.title)) {
///         ForEach(question.answers, id: \.self) { answer in
///             Text(answer)
///         }
///     }
///     ```
public class MultipleChoiceQuestion: ExitPollQuestion {
    public let answers: [String]

    public init(title: String, saveToSession: Bool, answers: [String]) {
        self.answers = answers
        super.init(title: title, saveToSession: saveToSession)
    }

    /// Checks if the given answer is valid for this question.
    public func isValidAnswer(_ answer: String) -> Bool {
        return answers.contains(answer)
    }
}

/// ScaleQuestion represents a question with a numeric scale.
/// - Suggested Presentation:
///   - Use a Slider in SwiftUI with range defined by `min` and `max`.
///   - Display `minLabel` and `maxLabel` as annotations.
///   - SwiftUI example:
///     ```swift
///     VStack {
///         Text(question.title)
///         Slider(value: $answer, in: question.min...question.max)
///         HStack {
///             Text(question.minLabel)
///             Spacer()
///             Text(question.maxLabel)
///         }
///     }
///     ```
public class ScaleQuestion: ExitPollQuestion {
    public let min: Int
    public let max: Int
    public let minLabel: String
    public let maxLabel: String

    public init(title: String, saveToSession: Bool, min: Int, max: Int, minLabel: String, maxLabel: String) {
        self.min = min
        self.max = max
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        super.init(title: title, saveToSession: saveToSession)
    }

    /// Validates if the given value is within the scale range.
    public func isValidValue(_ value: Int) -> Bool {
        return value >= min && value <= max
    }
}


public class VoiceQuestion: ExitPollQuestion {
    public let maxResponseLength: Int

    public init(title: String, saveToSession: Bool, maxResponseLength: Int) {
        self.maxResponseLength = maxResponseLength
        super.init(title: title, saveToSession: saveToSession)
    }
}
