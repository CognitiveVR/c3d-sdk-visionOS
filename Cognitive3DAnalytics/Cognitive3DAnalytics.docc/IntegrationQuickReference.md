# Integration Quick Reference

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

This guide provides a quick reference for integrating the Cognitive3D Analytics SDK into a visionOS application.

## 1. Import the Framework

```swift
import Cognitive3DAnalytics
```

## 2. Initial Setup in App

### Initialize the SDK at App Startup

```swift
// In your App struct's init method
init() {
    // Initialize the C3D SDK when app starts up
    cognitiveSDKInit()
}
```

### Configure the SDK

```swift
func cognitiveSDKInit() {
    let sceneData = SceneData(
        sceneName: appModel.sceneInfo.name,
        sceneId: appModel.sceneInfo.id,
        versionNumber: appModel.sceneInfo.version,
        versionId: appModel.sceneInfo.versionId
    )

    let core = Cognitive3DAnalyticsCore.shared

    let settings = CoreSettings()
    settings.customEventBatchSize = 64
    settings.defaultSceneName = sceneData.sceneName
    settings.allSceneData = [sceneData]

    settings.loggingLevel = .all
    settings.isDebugVerbose = isDebugVerbose

    let apiKey = Bundle.main.object(forInfoDictionaryKey: "APPLICATION_API_KEY") as? String ?? "default-value"
    settings.apiKey = apiKey

    core.setParticipantId(appModel.participantId)
    core.setParticipantFullName(appModel.participantFullName)

    // Start synchronous initialization
    Task {
        do {
            try await core.configure(with: settings)
            // Register code related to dynamic objects
            configureDynamicObject(settings)
            core.config?.shouldEndSessionOnBackground = false
        } catch {
            print("Failed to configure Cognitive3D Analytics: \(error)")
        }
    }
}

```

### Set Up Scene Phase Handling

```swift
// In your app's WindowGroup
WindowGroup {
    ContentView()
        // Add this modifier to enable scene phase handling
        .observeCognitive3DScenePhase()
}
```

## 3. Dynamic Objects Setup

### Register Components and Systems

```swift
fileprivate func configureDynamicObject(_ settings: CoreSettings) {
    // Register the dynamic component
    DynamicComponent.registerComponent()
    
    // Register the dynamic object system
    DynamicObjectSystem.registerSystem()
}
```

### Configure Dynamic Objects in Scene

```swift
func configureDynamicObjects(rootEntity: Entity) async {
    guard let objManager = Cognitive3DAnalyticsCore.shared.dynamicDataManager else {
        return
    }
    
    // Find all entities with DynamicComponent
    let dynamicEntities = findEntitiesWithComponent(rootEntity, componentType: DynamicComponent.self)
    
    // Register each dynamic object with the SDK
    for (entity, comp) in dynamicEntities {
        await objManager.registerDynamicObject(id: comp.dynamicId, name: comp.name, mesh: comp.mesh)
    }
}
```

## 4. Content Entity for Raycasting

This is required for gaze tracking to record gazes with `RealityKit` entities that have a `DynamicComponent`.

```swift
// In your RealityView setup
if let contentEntity = try? await Entity(named: "YourScene", in: realityKitContentBundle) {
    // ...
    
    // Provide the entity to the SDK for raycasting and collision detection
    let core = Cognitive3DAnalyticsCore.shared
    core.contentEntity = contentEntity
}
```

## 5. Session Management

### Implement Session Delegates

```swift
// Conform to SessionDelegate
class YourAppModel: SessionDelegate {
    // Handle session end events
    nonisolated func sessionDidEnd(sessionId: String, sessionState: SessionState) {
        Task { @MainActor in
            switch sessionState {
            case .endedIdle(timeInterval: let timeInterval):
                // Handle idle timeout
                
            case .endedBackground:
                // Handle app going to background
                
            default:
                // Handle other cases
            }
        }
    }
}

// Conform to IdleSessionDelegate
class YourAppModel: IdleSessionDelegate {
    nonisolated func sessionDidEndDueToIdle(sessionId: String, idleDuration: TimeInterval) {
        Task { @MainActor in
            // Handle idle session end
        }
    }
}
```

### Start and End Sessions

```swift
// Start a session
Cognitive3DAnalyticsCore.shared.startSession()

// End a session
Cognitive3DAnalyticsCore.shared.endSession()
```

## 6. Creating and Sending Custom Events

```swift
func createCustomEvent(dynamicId: String) {
    let core = Cognitive3DAnalyticsCore.shared

    // Create an event
    let customEvent = CustomEvent(
        name: "tapEvent",
        properties: [
            "timestamp": Date().timeIntervalSince1970
        ],
        dynamicObjectId: dynamicId,
        core: core
    )

    let success = customEvent.send(nil)
    print("custom event \(success)")
}
```

## 7. Working with Surveys

```swift
// Create an exit poll survey
let exitPollSurvey = ExitPollSurveyViewModel()
exitPollSurvey.loadSurvey(hook: "your-survey-hook")

// Submit survey answers
Task {
    let result = await exitPollSurvey.sendSurveyAnswers()
    switch result {
    case .success:
        print("Survey answers submitted successfully.")
    case .failure(let error):
        print("Failed to submit survey answers: \(error)")
    }
}
```

## 8. Changing Scenes

```swift
// Set a different scene during runtime
Cognitive3DAnalyticsCore.shared.setSceneById(
    sceneId: "new-scene-id", 
    version: 1, 
    versionId: 1234
)
```
