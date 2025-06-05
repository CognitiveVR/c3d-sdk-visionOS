# Dynamic Objects

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

In visionOS & RealityKit, the class akin to a game object is the [`Entity`](https://developer.apple.com/documentation/realitykit/entity) class.

More information is on the [Cognitvie 3D website](https://docs.cognitive3d.com/#read-the-docs).

## Using dynamic objects in the Swift C3D SDK

To use dynamic objects, you will need to add 3 files into your project in Xcode; these modules are distributed with the C3D framework:

 * `DynamicObjectSystem.swift`
 * `DynamicComponent.swift`
 * `ImmersiveView+DynamicObject.swift`
 
The Dynamic Object component allows you to track the position and state of GameObjects during the Participant's session. These can be used to track non player characters (NPC), and interactive objects.

The reason that some of the files are not in the SDK is due to a limitation with Reality Composer Pro (RCP); at this time, the `DynamicComponent` module need to placed inside the Reality Composer Pro folder.

> Note: You may need to rename the class in the ImmersiveView extension to match the name of your immersive scene.

```swift
/// ImmersiveView extension for dynamic objects handling
extension ImmersiveView {
```

### Configuring the SDK

> Note: to use the dynamic objects features, you need to register the 2 classes at runtime.

```swift
DynamicComponent.registerComponent()

DynamicObjectSystem.registerSystem()
```

### Using the C3D with a `RealityView` & Reality Composer Pro

 * the following shows how dynamic objects could be registered in with a `RealityView`
 * the entities are added to a `RealityView` using a RCP scene

```swift
func configureDynamicObjects(rootEntity: Entity) {

    print("configureDynamicObjects - register them with the C3D server for the current session")

    guard let objManager = Cognitive3DAnalyticsCore.shared.dynamicDataManager else {
        return
    }

    // get a list of all the dynamic objects
    let dynamicEntities = findEntitiesWithComponent(rootEntity, componentType: DynamicComponent.self)
    for (entity, comp) in dynamicEntities {
        print("add entity \(entity.name) with id \(comp.dynamicId)")
        // Register the obejct with the C3D SDK. This method will post the object's information.
        objManager.registerDynamicObject(id: comp.dynamicId, name: comp.name, mesh: comp.mesh)
    }
}

func findEntitiesWithComponent<T: Component>(_ entity: Entity, componentType: T.Type, isDebug: Bool = false
) -> [(entity: Entity, component: T)] {
    var foundEntities: [(entity: Entity, component: T)] = []

    func searchEntities(_ currentEntity: Entity, depth: Int = 0) {
        let indent = String(repeating: "    ", count: depth)

        // Check if the entity has the specified component
        if let component = currentEntity.components[componentType] {
            foundEntities.append((entity: currentEntity, component: component))
        }

        // Recursively search children
        for child in currentEntity.children {
            searchEntities(child, depth: depth + 1)
        }
    }

    // Start the search
    searchEntities(entity)

    return foundEntities
}
```

```swift
RealityView { content, attachments in
    // Add the initial RealityKit content
    if let immersiveContentEntity = try? await Entity(
        named: appModel.sceneInfo.usdName, in: realityKitContentBundle)
    {
        contentEntity = immersiveContentEntity
        content.add(immersiveContentEntity)

        let core = Cognitive3DAnalyticsCore.shared
        // This is required to perform ray casts & collision detection with
        // gaze tracking & dynamic objects.
        core.contentEntity = contentEntity

        configureDynamicObjects(rootEntity: immersiveContentEntity)
    }
```

### DynamicObjectSystem

The dynamic object system is the update loop in which dynamic objects can be registered or removed from tracking. When the loop is running, the `System` will get the positions etc. from the `RealityKit` entity that has a `DynamicComponent` component and record the data which will be subsequently posted to the C3D back end.

```swift
public func update(context: SceneUpdateContext) {
    // Process all entities with DynamicComponent during rendering
    for entity in context.entities(matching: Self.query, updatingSystemWhen: .rendering) {
        guard let component = entity.components[DynamicComponent.self] else { continue }

        // Check if the entity is no longer part of the hierarchy or is inactive
        if entity.parent == nil || !entity.isActive {
            handleEnabledStateChange(entity, component: component)
            continue // Skip further processing for this entity
        }

        let properties = [["enabled" : AnyCodable(true)]]

        dynamicManager.recordDynamicObject(
            id: component.dynamicId,
            position: entity.position,
            rotation: entity.orientation,
            scale: entity.scale,
            positionThreshold: component.positionThreshod,
            rotationThreshold: component.rotationThreshod,
            scaleThreshold: component.scaleThreshold,
            updateRate: component.updateRate,
            properties: properties
        )
    }
}
```

### DynamicComponent

The dynamic component is associated with a `RealityView` `Entity` in either RCP or in code at run-time.  The custom component has properties that get associated with an entity to:

 * associate the object by an ID with the C3D analytics session
 * set parameters for the various update thresholds

When using the component with RCP, the source code needs to be copied into the RCP project folder to enable the editor to automatically load the custom component & make it available in the IDE.

![Dynamic Component in RCP](DynamicComponent-RCP)

[Link to Apple developer documentation](https://developer.apple.com/documentation/visionos/designing-realitykit-content-with-reality-composer-pro)

Using the custom component in code.

```swift
struct ContentView: View {
    var body: some View {
        RealityView { content in
            // Create an entity and add the custom component
            let dynamicEntity = ModelEntity(mesh: .generateSphere(radius: 0.1))
            let component = DynamicComponent()
            component.name = "Obj1"
            component.mesh = "Obj1"
            component.dynamicId = "107AAA776D144C2C9796B84A9DD3F113"
            dynamicEntity.components.set(component)
            
            // Add the entity to the scene
            content.add(dynamicEntity)
        }
    }
}
```

### Hands as dynamic objects

visionOS supports hand tracking and in the C3D SDK this is supported using dynamic objects.

It requires hand tracking to be authorized by the user; the hand dynamic objects get created internal to the SDK.  Authorization requires adding a entry to the info plist for applications using the C3D SDK.

```
<key>NSHandsTrackingUsageDescription</key>
<string>Hand tracking is required by the analytics SDK</string>
```

[Apple documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nshandstrackingusagedescription)

When viewing a session in the scene viewer, the recorded data for the hand position and rotation will be played back visualized with hand meshes.

Note: hand tracking is not available in the simulator; the relevant code in the SDK is conditionally compiled.

### Using dynamic objects with SwiftUI views

In visionOS, it is desirable to know the positions of SwiftUI view and also record gazes with the view. 

How this can be achieved is using `GeometryReader3D` & `GeometryProxy3D` with dynamic objects.  A `PositionTrackerView` is added to the content view for each window in an application.

This also requires adding a data model and corresponding code in a `RealityKit` view to update the entities in the scene.  The entity would have the `DynamicComponent` added to it in code or using Reality Composer Pro.


![Dynamic Proxy flow chart](dynamic-flow)


#### In the application main

```swift
@main
struct Dynamic_windows_multipleApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasLaunched = false

    @State private var appModel = AppModel()

    /// model for working with proxy dynamic objects
    @State private var dynamicViewsModel = DynamicObjectsModel()

    init() {
        cognitiveSDKInit()
    }

    var body: some Scene {
        // The primary window.
        WindowGroup("Primary") {
            ContentView()
                .environment(appModel)
                .environment(dynamicViewsModel)
        }.onChange(of: scenePhase) {
            if !hasLaunched {
                hasLaunched = true
                openWindow(id: "Secondary")
            }
        }

        // The second window.
        WindowGroup("Secondary", id: "Secondary") {
            // The second content view that contains a Window Position Tracker View.
            Content2View()
                .environment(appModel)
                .environment(dynamicViewsModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .environment(dynamicViewsModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }

```

### Adding a `PositionTrackerView` into a content view

> Note: the use of a `ZStack` and the placement of the view at top of the stack.  If the position tracker is at the bottom layer of the `ZStack` it will cause the views to be floating above the window as the tracker view has a depth to as a result of using a `GeometryReader3D`. 

```swift
#Preview {
    ZStack {
        VStack() {
            Text("using a Z Stack")
                .padding(.top, 50)
            Divider()
            Text("Testing...")
                .padding(.bottom, 50)
        }

        PositionTrackerView(dynamicId: "ABCD1234", displayMode: .hidden)
            .environment(ProxyDynamicObjectsModel())
    }.glassBackgroundEffect()
}
```

#### In the view that displays the `RealityKit` entities

```swift
@Environment(DynamicObjectsModel.self) private var dynamicViewsModel
```

```swift
update: { content, _ in
    if isRealityViewReady {
        updateDynamicObject(content: content)
    }
}
```

```swift
/// Update the proxy dynamic objects with data from the SwiftUI view's transform.
private func updateDynamicObject(content: RealityViewContent) {
    dynamicEntities.forEach { entity in
        guard let component = entity.components[DynamicComponent.self],
            let windowModel = dynamicViewsModel.viewModels[component.dynamicId]
        else {
            // It is possible there are dynamic objects in the scene that are not associated
            // with a SwiftUI view & thus a window model.
            return
        }

        // Get geometry for this entity
        let geometry = dynamicViewsModel.viewGeometries[component.dynamicId]

        // Apply transforms using the model
        windowModel.applyTransformsToEntity(
            entity,
            using: metricsConverter,
            geometry: geometry,
            useOffset: useOffset
        )
    }
}
```




