# Exit Poll Survey View Model

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

The `ExitPollSurveyViewModel` is the core class responsible for managing the state and logic of the exit poll survey feature. It handles fetching survey questions, managing user responses, and providing state information for SwiftUI views.

---

## Features
- **Async Survey Fetching:** Fetches survey questions from the backend based on a unique hook.
- **User Response Handling:** Tracks user responses and updates the state of the survey dynamically.
- **Error Handling:** Includes structured error reporting with `ExitPollSurveyError`.
- **SwiftUI Integration:** Designed to integrate seamlessly with SwiftUI views using `@EnvironmentObject`.

---

## Key Methods

### `fetchSurvey(hook:)`

Fetches the survey data based on the provided hook. Handles network requests and updates the view model's state.

**Parameters:**
- `hook`: A unique identifier for the survey to fetch.

**Returns:**
- A `Result<Void, ExitPollSurveyError>` indicating success or failure.

**Example Usage:**
```swift
Task {
    let result = await viewModel.fetchSurvey(hook: "sampleHook123")
    switch result {
    case .success:
        print("Survey fetched successfully.")
    case .failure(let error):
        switch error {
        case .networkError(let message):
            print("Network Error: \(message)")
        case .invalidResponse:
            print("Invalid response received.")
        case .noQuestionsRetrieved:
            print("No questions retrieved for this survey.")
        }
    }
}
```

---

### `setAnswer(_ answer: Answer, forQuestionAt index: Int)`

Records the user's answer for a specific question.

**Parameters:**
- `answer`: The user's response to the question.
- `index`: The index of the question in the survey.

**Example Usage:**
```swift
viewModel.setAnswer(.boolean(true), forQuestionAt: 0)
```

---

### `submitSurvey()`

Submits the user's responses to the backend.

**Returns:**
- A `Result<Void, ExitPollSurveyError>` indicating success or failure.

**Example Usage:**
```swift
Task {
    let result = await viewModel.submitSurvey()
    switch result {
    case .success:
        print("Survey submitted successfully.")
    case .failure(let error):
        print("Error submitting survey: \(error.localizedDescription)")
    }
}
```

---

## SwiftUI Integration

### Environment Setup

To use the `ExitPollSurveyViewModel` with SwiftUI, provide it as an `@EnvironmentObject`.

```swift
@main
struct MyApp: App {
    @StateObject private var viewModel = ExitPollSurveyViewModel()

    var body: some Scene {
        WindowGroup {
            ExitPollSurveyView()
                .environmentObject(viewModel)
        }
    }
}
```

---

### Example SwiftUI View

Here’s an example of how to use the view model in a SwiftUI view:

```swift
import SwiftUI

struct ExitPollSurveyView: View {
    @EnvironmentObject var viewModel: ExitPollSurveyViewModel
    @State private var currentIndex = 0

    var body: some View {
        VStack {
            if viewModel.isLoading {
                Text("Loading Survey...")
            } else if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            } else if currentIndex < viewModel.surveyQuestions.count {
                VStack {
                    Text(viewModel.surveyQuestions[currentIndex].title)
                    Button("Confirm") {
                        moveToNextQuestion()
                    }
                }
            } else {
                Text("Thank you for completing the survey!")
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchSurvey(hook: "sampleHook123")
            }
        }
    }

    private func moveToNextQuestion() {
        currentIndex += 1
    }
}
```

---

### Error Handling

The view model uses `ExitPollSurveyError` to provide structured error handling. Common error cases include:
- **Network Errors:** Represented as `.networkError(String)`.
- **Invalid Response:** If the backend returns unexpected data.
- **No Questions Retrieved:** When the survey data is empty.

**Example:**
```swift
Task {
    do {
        let result = try await viewModel.fetchSurvey(hook: "sampleHook123")
        // Handle success
    } catch let error as ExitPollSurveyError {
        // Handle specific error cases
    } catch {
        // Handle unexpected errors
    }
}
```


[Exit Poll Question SwiftUI views](ExitPollSwiftUIViewsDocumentation)

---
