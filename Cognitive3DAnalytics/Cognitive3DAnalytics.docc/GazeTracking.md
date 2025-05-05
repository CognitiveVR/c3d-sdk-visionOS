# Gaze tracking

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

Gaze tracking is a key feature in the C3D analytics SDK. For this feature to be enabled, the visionOS app needs to have opened an immersive space. Gaze records the HMD position over time and the direction of the eyes at a set interval.

The gaze tracker works with an `ARSession` to get the transform for the Apple Vision Pro (HMD).

The coordinate system used by visionOS is different from what is used in C3D; the Swift SDK will convert the coordinates before posting the gaze stream.  The z value decreases as an object moves away the HMD; this is referred to as a right handed coordinate system. 

## Gaze tracking and dynamic objects

Gazes can also be tracking when a raycast collides with a dynamic object.  The dynamic object needs to have a collider component added to it in a scene file in Reality Composer Pro or added in code.


```swift
/// Create a cube & add a `DynamicComponent` to it.
private func createCube() -> ModelEntity {
    let cubeEntity = ModelEntity(mesh: .generateBox(size: 0.2))  // Cube with 20 cm sides
    cubeEntity.name = "Collider Cube"

    let material = SimpleMaterial(color: .green, isMetallic: false)
    cubeEntity.model?.materials = [material]

    cubeEntity.position = [0, 2.0, -0.5]  // X: 0m, Y: 2m up, Z: 50cm away

    cubeEntity.collision = CollisionComponent(
        shapes: [.generateBox(size: [1.0, 1.0, 1.0])],
        mode: .colliding,
        filter: .default
    )

    // Now to add a custom conpoment to faciitate dynamic object snapshot recording.
    var component = DynamicComponent()
    component.name = "Window_3"
    component.mesh = "Window_Proxy"
    component.dynamicId = "F1003EFBA6874239BC18B4123C35F877"
    cubeEntity.components.set(component)
    return cubeEntity
}

```

