# The Cognitive3D SDK for visionOS

Welcome! This SDK allows you to integrate your visionOS applications on Apple Vision Pro with Cognitive3D, which provides analytics and insights about your VR/AR/MR project. In addition, Cognitive3D empowers you to take actions that will improve users' engagement with your experience.

## Quick Integration

Get started with just **3 lines of code**:

```swift
import Cognitive3DAnalytics

// In your App's init or scene setup
try await Cognitive3DAnalyticsCore.setup(
    apiKey: "your-api-key",
    sceneName: "MainScene", 
    sceneId: "your-scene-id"
)
```

## Installation

### Swift Package Manager

Add the SDK to your project using Xcode:

1. **File → Add Package Dependencies**
2. **Enter the repository URL**: `https://github.com/CognitiveVR/c3d-sdk-visionOS`
3. **Select version**: Latest release
4. **Add to target**: Your visionOS app target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CognitiveVR/c3d-sdk-visionOS", from: "1.0.0")
]
```

### Manual Integration

1. **Download** the latest `Cognitive3DAnalytics.xcframework`
2. **Drag and drop** into your Xcode project
3. **Add to target**: Ensure it's linked to your app target

## Configuration

### Simple Setup (Recommended)

For most applications, use the simplified setup:

```swift
import Cognitive3DAnalytics

@main
struct MyVisionApp: App {
    init() {
        Task {
            do {
                try await Cognitive3DAnalyticsCore.setup(
                    apiKey: "your-api-key",
                    sceneName: "MainScene",
                    sceneId: "your-scene-id"
                )
            } catch {
                print("Failed to initialize Cognitive3D: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Advanced Configuration

For more control over SDK behavior:

```swift
try await Cognitive3DBuilder()
    .apiKey("your-api-key")
    .scene(name: "MainScene", id: "your-scene-id", version: 2)
    .logging(level: .warningsAndErrors, verbose: false)
    .batchSizes(.performance)          // High-frequency data collection
    .features(.comprehensive)          // All sensors and tracking
    .network(.default)                 // Standard network behavior
    .configure()
```

### Configuration Presets

Choose the right preset for your needs:

#### Batch Size Presets
- **`.default`**: Balanced performance (recommended)
- **`.performance`**: High-frequency collection for detailed analytics
- **`.conservative`**: Lower bandwidth/battery usage

#### Feature Presets
- **`.minimal`**: Basic analytics only
- **`.default`**: Standard sensor tracking (recommended)
- **`.comprehensive`**: All available sensors and features

#### Network Presets
- **`.default`**: Standard networking with offline support
- **`.debug`**: Verbose logging for development
- **`.networkOnly`**: Disable offline caching

### Environment-Specific Setup

```swift
#if DEBUG
// Development: verbose logging and debug features
try await Cognitive3DAnalyticsCore.setupDebug(
    apiKey: "dev-api-key",
    sceneName: "TestScene", 
    sceneId: "test-scene-id"
)
#else
// Production: optimized settings
try await Cognitive3DAnalyticsCore.setup(
    apiKey: "prod-api-key",
    sceneName: "MainScene", 
    sceneId: "main-scene-id"
)
#endif
```

## Getting Your API Key and Scene ID

1. **Sign up** at [dashboard.cognitive3d.com](https://dashboard.cognitive3d.com)
2. **Create a new project** for your visionOS application
3. **Upload your scene** (3D model in glTF format)
4. **Copy your API key** from the project settings
5. **Copy your scene ID** from the scene details page

## Error Handling

The SDK provides detailed error messages to help with integration:

```swift
do {
    try await Cognitive3DAnalyticsCore.setup(
        apiKey: apiKey,
        sceneName: sceneName,
        sceneId: sceneId
    )
} catch let error as Cognitive3DConfigurationError {
    print("Configuration error: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
} catch {
    print("Setup failed: \(error)")
}
```

## Validation and Debugging

### Setup Validation

Validate your configuration before initialization:

```swift
// Validate configuration before setup
let settings = CoreSettings(...)
let result = Cognitive3DAnalyticsCore.validateConfiguration(settings)

if result.isValid {
    print("✅ Configuration is valid")
    try await core.configure(with: settings)
} else {
    // Print detailed validation report
    result.printReport()
    
    // Or handle specific issues
    for issue in result.issues(withSeverity: .error) {
        print("❌ \(issue.message)")
        print("💡 \(issue.solution)")
    }
}
```

### Quick Validation

For simple validation checks:

```swift
// Quick boolean check
if Cognitive3DAnalyticsCore.isConfigurationValid(settings) {
    // Proceed with setup
} else {
    // Handle invalid configuration
    let errors = Cognitive3DSetupValidator.quickValidation(settings)
    print("Configuration errors: \(errors)")
}
```

### Runtime Validation

Check current SDK status:

```swift
// After SDK is configured
if let result = Cognitive3DAnalyticsCore.validateCurrentSetup() {
    result.printReport()
} else {
    print("SDK not configured")
}

// Simple print report
Cognitive3DAnalyticsCore.printValidationReport()
```

### Comprehensive Health Check

The setup validator checks:

- ✅ **Configuration validity**: API key format, scene data, batch sizes
- ✅ **Network connectivity**: Internet access, connection type
- ✅ **Device capabilities**: ARKit support, visionOS version compatibility  
- ✅ **Permissions**: Camera access, world sensing permissions
- ✅ **System resources**: Available storage, memory usage, battery level

### Legacy Debugging

For existing setups:

```swift
// Check if properly configured (legacy method)
if Cognitive3DAnalyticsCore.validateSetup() {
    print("✅ SDK configured successfully")
} else {
    print("❌ SDK configuration incomplete")
    
    // Get detailed debug information
    let debug = Cognitive3DAnalyticsCore.getDebugInformation()
    print("Debug info: \(debug)")
}
```

## Features

### Automatic Tracking
- **Gaze tracking**: Eye movement and attention patterns
- **Head tracking**: Position and orientation data
- **Hand tracking**: Hand poses and gestures (when enabled)
- **Device sensors**: Battery level, frame rate, device orientation

### Custom Events
```swift
// Track user interactions
let event = CustomEvent(name: "button_clicked", core: Cognitive3DAnalyticsCore.shared)
    .setProperty(key: "button_id", value: "main_menu")
    .setPosition(buttonPosition)
event.send()
```

### Dynamic Object Tracking
Track moving objects in your scene using RealityKit integration.

### Exit Poll Surveys
Collect user feedback with built-in survey capabilities.

## Performance Considerations

- **Automatic batching**: Data is efficiently batched before network transmission
- **Offline support**: Analytics continue working without internet connection
- **Background processing**: Minimal impact on your app's performance
- **Configurable intervals**: Adjust collection frequency based on your needs

## Migration from Previous Versions

If upgrading from an older version with complex configuration:

```swift
// Old way (still supported)
let settings = CoreSettings(
    defaultSceneName: "Scene",
    allSceneData: [sceneData],
    apiKey: "key",
    // ... 15+ other parameters
)
try await core.configure(with: settings)

// New simplified way
try await Cognitive3DAnalyticsCore.setup(
    apiKey: "key",
    sceneName: "Scene", 
    sceneId: "scene-id"
)
```

## Documentation

Comprehensive documentation is available at our developer portal:

[📖 **Go to the Docs**](http://docs.cognitive3d.com/visionos/get-started/)

## Requirements

- **visionOS 2.0+**
- **Xcode 16.0+**
- **Swift 6.0+**

## Support

- **Documentation**: [docs.cognitive3d.com](http://docs.cognitive3d.com/visionos/)
- **Dashboard**: [dashboard.cognitive3d.com](https://dashboard.cognitive3d.com)
- **Issues**: [GitHub Issues](https://github.com/CognitiveVR/c3d-sdk-visionOS/issues)

## License

This SDK is proprietary software. See the license agreement for terms of use.

