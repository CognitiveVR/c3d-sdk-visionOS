# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Cognitive3D Analytics SDK for visionOS, a Swift framework that provides analytics and insights for VR/AR/MR applications on Apple Vision Pro. The SDK tracks user behavior, gaze data, dynamic objects, custom events, and provides exit poll surveys.

## Claude Guidance

- If unsure about an analytics term or other specialized terms pause to ask the user for clarification

## Build Commands

### Building XCFramework
```bash
# Standard build (release)
./build_xcframework.sh

# Build with debug symbols (for development/debugging)
./build_with_debug_symbols.sh
```

### Testing
```bash
# Run all tests using Xcode
xcodebuild test -scheme Cognitive3DAnalytics -project Cognitive3D-Analytics-core.xcodeproj -destination "platform=visionOS Simulator,name=Apple Vision Pro"

# Run tests using test plan
xcodebuild test -testPlan Cognitive3DAnalytics -project Cognitive3D-Analytics-core.xcodeproj -destination "platform=visionOS Simulator,name=Apple Vision Pro"

# Run specific test class
xcodebuild test -scheme Cognitive3DAnalytics -project Cognitive3D-Analytics-core.xcodeproj -destination "platform=visionOS Simulator,name=Apple Vision Pro" -only-testing:c3d-swift-sdkTests/CustomEventTests
```

### Development Commands
```bash
# List available schemes and targets
xcodebuild -list -project Cognitive3D-Analytics-core.xcodeproj

# Build for development (debug configuration)
xcodebuild build -scheme Cognitive3DAnalytics -project Cognitive3D-Analytics-core.xcodeproj -configuration Debug

# Generate documentation
xcodebuild docbuild -scheme Cognitive3DAnalytics -project Cognitive3D-Analytics-core.xcodeproj -destination "generic/platform=visionOS"
```

## Architecture Overview

### Core Components

**Cognitive3DAnalyticsCore**: Main SDK entry point managing session lifecycle, configuration, and data collection coordination.

**Analytics Systems**:
- **GazeDataManager**: Tracks eye tracking and gaze patterns using ARKit
- **DynamicDataManager**: Manages dynamic object tracking and transform data
- **EventRecorder**: Handles custom events and sensor data recording
- **SensorRecorder**: Collects device sensors (battery, frame rate, pitch/yaw)

**Data Pipeline**:
- **Cache System**: `DataCacheSystem` and `DualFileCache` for offline data storage
- **Network Layer**: `NetworkAPIClient` handles batch uploads to Cognitive3D backend
- **Sync Services**: `AnalyticsSyncService` and `GazeSyncManager` coordinate data transmission

### Key Directories

- `Cognitive3DAnalytics/`: Main SDK source code
  - `Cache/`: Data caching and offline storage
  - `Model/`: Data models and core structures
  - `Exit Poll Survey/`: Survey UI and data collection
  - `DynamicObjects/`: Object tracking components
  - `HandTracking/`: Hand tracking integration
  - `Sensors/`: Device sensor recording
- `Systems/`: RealityKit ECS systems for dynamic object tracking
- `Components/`: RealityKit components for entity behavior
- `Extensions/`: Framework extensions and utilities
- `Cognitive3DAnalytics-coreTests/`: Comprehensive test suite

### Data Flow Architecture

1. **Session Management**: Core tracks app lifecycle and session states
2. **Data Collection**: Multiple recorders gather gaze, events, sensors, dynamic objects
3. **Caching**: Data stored locally using dual-file cache system for reliability
4. **Batching**: Network client batches requests based on configurable limits
5. **Upload**: Background sync services handle data transmission to backend

### Testing Framework

Uses Apple's Swift Testing framework with comprehensive test coverage:
- **Mock Classes**: Full network and data mocking in `MockClasses.swift`
- **Integration Tests**: End-to-end testing of data flow
- **Unit Tests**: Individual component testing
- **Network Tests**: API client and data transmission testing

### Platform Support

- **Target Platform**: visionOS 2.0+
- **Architecture**: Universal (arm64 device + simulator)
- **Distribution**: XCFramework with debug symbols support
- **Documentation**: DocC integration for API documentation

### Configuration

The SDK uses a configuration-driven approach:
- Scene data management through `Config` class
- Network environment configuration via `NetworkEnvironment`
- Customizable batch sizes and upload intervals
- Support for custom API endpoints and authentication

## Actionable Error Messages & Setup Validation Plan

### Implementation Phases

#### Phase 1: Enhanced Configuration Validation (High Priority) ✅ COMPLETED
**Week 1-2**
- ✅ 1.1 Core Settings Validation: Add comprehensive validation to `CoreSettings.swift`
- ✅ 1.2 Pre-Configuration Health Check: Create `Cognitive3DSetupValidator` for setup validation

#### Phase 2: Runtime Error Enhancement (High Priority) 
**Week 3-4**
- 2.1 Session State Validation: Add strict state validation with clear guidance
- 2.2 Enhanced Network Error Handling: Detailed network error categorization with retry logic

#### Phase 3: Comprehensive Data Validation (Medium Priority)
**Week 5-6**
- 3.1 Custom Event Validation: Strict event validation with helpful error messages
- 3.2 Scene Data Validation: Enhanced validation for scene data and properties

#### Phase 4: User Experience Enhancements (Medium Priority)
**Week 7-8**
- 4.1 Setup Diagnostic Tool: Comprehensive diagnostic utility (`Cognitive3DDiagnostics`)
- 4.2 Error Recovery Guidance System: Interactive error recovery with actionable steps

### Key Improvements
- **Error Clarity**: 90% of errors include actionable recovery steps
- **Validation Coverage**: 100% of configuration parameters validated  
- **Silent Failures**: Eliminate all silent failure modes
- **User Experience**: Reduce support tickets by 70%, integration time by 50%

### New Error Types
- `Cognitive3DConfigurationError`: Enhanced configuration validation
- `SessionStateError`: Session state validation with clear guidance
- `NetworkError`: Detailed network error categorization
- `EventValidationError`: Custom event validation with limits
- `DiagnosticReport`: Comprehensive setup validation tool

### Implementation Progress

#### ✅ Phase 1 Completed: Enhanced Configuration Validation
**Files Added/Modified:**
- `CoreSettings.swift`: Added comprehensive validation with 7 validation categories
- `Cognitive3DConfigurationHelpers.swift`: Enhanced error types with actionable messages
- `Cognitive3DSetupValidator.swift`: Pre-configuration health check utility
- `Cognitive3DBuilder.swift`: Integrated automatic validation during setup
- `Cognitive3DAnalyticsCore.swift`: Added validation convenience methods
- Test files: `CoreSettingsValidationTests.swift`, `SetupValidatorTests.swift`

**Key Features Implemented:**
- **Configuration Validation**: API key format, scene data integrity, parameter bounds
- **Environment Validation**: Network connectivity, device capabilities, permissions
- **System Resource Checks**: Storage, memory, battery level monitoring
- **Structured Error Reporting**: Categorized issues with severity levels and recovery guidance
- **Multiple Validation Modes**: Full validation, quick checks, runtime validation

#### 🔄 Next: Phase 2 - Runtime Error Enhancement
**Ready to implement:**
- 2.1 Session State Validation: Add strict state validation with clear guidance
- 2.2 Enhanced Network Error Handling: Detailed network error categorization with retry logic

### Usage Examples
```swift
// Configuration validation before setup
let result = Cognitive3DSetupValidator.validateConfiguration(settings)
if result.isValid {
    try await core.configure(with: settings)
} else {
    result.printReport() // Comprehensive validation report
}

// Quick validation
if Cognitive3DAnalyticsCore.isConfigurationValid(settings) {
    // Proceed with setup
} else {
    let errors = Cognitive3DSetupValidator.quickValidation(settings)
    print("Errors: \(errors)")
}

// Runtime validation
Cognitive3DAnalyticsCore.printValidationReport()

// Manual validation
let validation = Cognitive3DSetupValidator.validateConfiguration(settings)
for issue in validation.issues(withSeverity: .error) {
    print("❌ \(issue.message)")
    print("💡 \(issue.solution)")
}
```

### Validation Categories
- **Configuration**: API key, scene data, batch sizes, intervals
- **Network**: Connectivity, connection type, reachability  
- **Device**: ARKit support, visionOS version, hardware capabilities
- **Permissions**: Camera access, world sensing authorization
- **System**: Storage space, memory usage, battery level