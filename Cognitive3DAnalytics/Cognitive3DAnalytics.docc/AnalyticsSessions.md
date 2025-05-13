# Analytic Sessions

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

This guide provides information on how sessions work in the Cognitive 3D SDK and configuring an analytics session.

## Configuring the SDK

The C3D SDK requires multiple steps to integrate it with an application:

 * initialize the C3D SDK
 * register `scenePhase` handling using `Combine`
 * register classes used for Dynamic object support along with hooking into the view that opens an immersive scene

*TODO add link to sample code here*

### init the SDK

```swift
struct MyApp: App {

    init() {
        cognitiveSDKInit()
    }

    ...

    // Initialize the C3D analytics SDK
    fileprivate func cognitiveSDKInit() {
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


### configure `scenePhase` handling

`scenePhase` handling is using `Combine`.

```swift
@Environment(\.scenePhase) private var scenePhase

WindowGroup(id: "App") {
    ContentView()
        .observeCognitive3DScenePhase()
}
```


### Dynamic objects registering classes.


```swift
DynamicComponent.registerComponent()

DynamicObjectSystem.registerSystem()
```

## Starting a session

```swift

import Cognitive3DAnalytics

...

let analytics = Cognitive3DAnalyticsCore.shared
Task {
    analytics.setParticipantId(appModel.participantId)
    analytics.setParticipantFullName(appModel.participantFullName)

    if await analytics.startSession() {
    } else {
        print("✎ Failed to start session")
    }
}

```

## Ending a session

```swift
import Cognitive3DAnalytics

...

let analytics = Cognitive3DAnalyticsCore.shared
Task {
    if await analytics.endSession() {

    ...

    } else {
        print("✎ Failed to end session")
    }
}

```

As an application developer, you want to think about under what conditions do you want to end a session and you have the option to make use of C3D SDK settings to automatically end a session when the app is idling or has gone into the background.


```swift
/// Set to true to end sessions when the idle threshold is passed.
public var shouldEndSessionOnIdle: Bool = false

/// Idle time out threshold
public var idleThreshold: TimeInterval = 10.0

/// Set this to true to send any recorded data when the app has the `inActive` scenePhase
public var shouldSendDataOnInactive = true

/// Set this to true such that the analytics SDK will end a session when the app has entered the `background` scenePhase.
public var shouldEndSessionOnBackground = false

```

Some questions to ask yourself:

 * what should happen to a session when the taps the digital crown?
 * what should happen to a session if the user can exit & reenter an immersive space?

The C3D SDK using combine can monitor what happens to the `scenePhase` for an application to end a session when an application enters the `background`.

## SDK settings

### Automatically ending a session

In SwiftUI & visionOS, an application can be in the following states using `scenePhase`:

    - active
    - inactive
    - background

The C3D SDK has a dedicated class ``ScenePhaseManager`` for working with the `scenePhase`s.

Sessions can be ended by the C3D SDK when certain conditions occurs like the application going into the background; in the ``Config`` class there are properties to control the SDK behaviour.

```swift
/// Set to true to end sessions when the idle threshold is passed.
public var shouldEndSessionOnIdle: Bool = false

/// Idle time out threshold
public var idleThreshold: TimeInterval = 10.0

/// Set this to true to send any recorded data when the app has the `inActive` scenePhase
public var shouldSendDataOnInactive = true

/// Set this to true such that the analytics SDK will end a session when the app has entered the `background` scenePhase.
public var shouldEndSessionOnBackground = false
```

