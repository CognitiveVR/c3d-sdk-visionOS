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