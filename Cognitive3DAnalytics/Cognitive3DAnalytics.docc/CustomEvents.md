# Custom Events

@Metadata {
   @TitleHeading(Framework)
   @PageImage(purpose: icon, source: C3D-logo.svg, alt: "Cognitive3D Analytics icon")
}

**Custom Events** are a simple but important way Cognitive3D can record data from your experience.

Custom Events automatically record `x,y,z` coordinates. If the position is not provided it will use the position of the HMD. In conjunction with Gaze tracking, coordinates gives you the ability to map out how your Participants are interacting with your experience in 3D space.

----

## Setup

Custom Events are visible on the Dashboard on the [Session Details](https://docs.cognitive3d.com/dashboard/session-details/) page and [Analysis Tool](https://docs.cognitive3d.com/dashboard/simple-analysis/). They are also a common feature of the [Objectives](https://docs.cognitive3d.com/dashboard/objectives-summary/) system.

## Creating and Sending Events

Each example below shows both the chained approach (for concise code) and the step-by-step approach.

### Simple Event

The most basic event with no additional properties or position:

// Step-by-step approach
func recordSimpleEvent() async {
    let customEvent = CustomEvent(name: "ButtonClick", core: analytics)
    let success = customEvent.send()

    if success { 
        print("event sent")
    }
}
```

### Event with Position

Adding a specific position to an event:

```swift
func recordEventWithPosition() async {
    let buttonPosition: [Double] = [1.0, 0.8, 2.5]
    
    // Chained approach
    let success = CustomEvent(name: "ButtonClick", core: analytics)
        .send(buttonPosition)
    
    // Step-by-step approach
    let customEvent = CustomEvent(name: "ButtonClick", core: analytics)
    let success = customEvent.send(buttonPosition)
}
```

### Event with Properties

Adding properties to an event:

```swift
func recordEventWithProperties() async {
    // Chained approach with individual properties
    let success = CustomEvent(name: "MenuSelection", core: analytics)
        .setProperty(key: "Menu", value: "Main Menu")
        .setProperty(key: "Item", value: "Settings")
        .send()
    
    // Step-by-step approach with individual properties
    let customEvent = CustomEvent(name: "MenuSelection", core: analytics)
    customEvent.setProperty(key: "Menu", value: "Main Menu")
    customEvent.setProperty(key: "Item", value: "Settings")
    let success = customEvent.send()
    
    // Using a dictionary of properties
    let properties: [String: Any] = [
        "Menu": "Main Menu",
        "Item": "Settings"
    ]
    
    let success = CustomEvent(name: "MenuSelection", core: analytics)
        .setProperties(properties)
        .send()
}
```

### Event with Properties and Position

Combining properties and position:

```swift
func recordEventWithPropertiesAndPosition() async {
    let menuPosition: [Double] = [1.5, 0.9, 2.2]
    
    // Chained approach
    let success = CustomEvent(name: "MenuSelection", core: analytics)
        .setProperty(key: "Menu", value: "Main Menu")
        .setProperty(key: "Item", value: "Settings")
        .send(menuPosition)
    
    // Step-by-step approach
    let customEvent = CustomEvent(name: "MenuSelection", core: analytics)
    customEvent.setProperty(key: "Menu", value: "Main Menu")
    customEvent.setProperty(key: "Item", value: "Settings")
    let success = customEvent.send(menuPosition)
}
```

## High Priority Events

For important events that need to be processed with higher priority:

```swift
func recordHighPriorityEvent() async {
    // Simple high priority event
    let success = CustomEvent(name: "PurchaseComplete", core: analytics)
        .sendWithHighPriority()
    
    // High priority event with position
    let position: [Double] = [1.0, 0.8, 2.5]
    let success = CustomEvent(name: "ErrorOccurred", core: analytics)
        .sendWithHighPriority(position)
    
    // High priority event with properties
    let success = CustomEvent(name: "PurchaseComplete", core: analytics)
        .setProperty(key: "Amount", value: 49.99)
        .setProperty(key: "Currency", value: "USD")
        .sendWithHighPriority()
    
    // High priority event with properties and position
    let position: [Double] = [1.5, 0.9, 2.2]
    let success = CustomEvent(name: "ErrorOccurred", core: analytics)
        .setProperty(key: "ErrorCode", value: 404)
        .setProperty(key: "Message", value: "Resource not found")
        .sendWithHighPriority(position)
}
```

## Dynamic Object Events

Events can be associated with Dynamic Objects to track interactions with specific objects:

```swift
func recordDynamicObjectEvents(dynamicId: String) async {
    // Simple dynamic object event
    let success = CustomEvent(name: "ObjectInteraction", core: analytics)
        .setDynamicObject(dynamicId)
        .send()
    
    // Dynamic object event with properties
    let success = CustomEvent(name: "ObjectInteraction", core: analytics)
        .setDynamicObject(dynamicId)
        .setProperty(key: "Interaction", value: "Grab")
        .setProperty(key: "Duration", value: 2.5)
        .send()
    
    // Dynamic object event with properties and position
    let position: [Double] = [1.5, 0.9, 2.2]
    let success = CustomEvent(name: "ObjectInteraction", core: analytics)
        .setDynamicObject(dynamicId)
        .setProperty(key: "Interaction", value: "Grab")
        .setProperty(key: "Duration", value: 2.5)
        .send(position)
    
    // High priority dynamic object event
    let success = CustomEvent(name: "CriticalObjectInteraction", core: analytics)
        .setDynamicObject(dynamicId)
        .setProperty(key: "Interaction", value: "Delete")
        .sendWithHighPriority()
}
```

## Alternative Initialization Methods

You can also create events with properties and dynamic objects directly in the initializer:

```swift
// Initialize with properties
let properties: [String: Any] = [
    "Menu": "Main Menu",
    "Item": "Settings"
]

let customEvent = CustomEvent(
    name: "MenuSelection", 
    properties: properties,
    core: analytics
)
let success = customEvent.send()

// Initialize with dynamic object
let customEvent = CustomEvent(
    name: "ObjectInteraction",
    dynamicObjectId: "object-123",
    core: analytics
)
let success = customEvent.send()

// Initialize with properties and dynamic object
let properties: [String: Any] = [
    "Interaction": "Grab",
    "Duration": 2.5
]

let customEvent = CustomEvent(
    name: "ObjectInteraction",
    properties: properties,
    dynamicObjectId: "object-123",
    core: analytics
)
let success = customEvent.send()
```

While all events are eventually sent to the server, high-priority events are processed sooner in the queue, making them suitable for critical user interactions or important milestones in your application.
