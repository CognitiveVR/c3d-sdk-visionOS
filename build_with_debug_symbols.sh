#!/bin/bash

# build XCframework for the Swift C3D anaytics SDK with debug symbols

# Enable error reporting
set -e

# Configuration
FRAMEWORK_NAME="Cognitive3DAnalytics"
SCHEME_NAME="$FRAMEWORK_NAME"
PROJECT_NAME="Cognitive3D-Analytics-core.xcodeproj"
OUTPUT_DIR="Build-Cognitive3DAnalytics"

echo "Starting build process..."
echo "Framework: $FRAMEWORK_NAME"
echo "Output Directory: $OUTPUT_DIR"

# Clean build directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Documentation"
mkdir -p "$OUTPUT_DIR/archives"

# Build for visionOS Device
echo "Building visionOS device archive..."
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS" \
    -archivePath "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    ONLY_ACTIVE_ARCH=NO \
    GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
    STRIP_INSTALLED_PRODUCT=NO

# Build for visionOS Simulator
echo "Building visionOS simulator archive..."
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS Simulator" \
    -archivePath "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
    ONLY_ACTIVE_ARCH=NO \
    GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
    STRIP_INSTALLED_PRODUCT=NO

# Build DocC Documentation
echo "Building DocC documentation..."
xcodebuild docbuild \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS" \
    -derivedDataPath "$OUTPUT_DIR/DerivedData" \
    OTHER_DOCC_FLAGS="--transform-for-static-hosting --hosting-base-path $FRAMEWORK_NAME --output-path $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive"

# Function to verify dSYM structure
verify_dsym() {
    local archive_path="$1"
    local dsym_path="$archive_path/dSYMs/$FRAMEWORK_NAME.framework.dSYM"

    if [ ! -d "$dsym_path" ]; then
        echo "❌ dSYM not found at: $dsym_path"
        return 1
    fi

    if [ ! -d "$dsym_path/Contents/Resources/DWARF" ]; then
        echo "❌ DWARF directory not found in dSYM"
        return 1
    fi

    if [ ! -f "$dsym_path/Contents/Resources/DWARF/$FRAMEWORK_NAME" ]; then
        echo "❌ DWARF file not found for framework"
        return 1
    fi

    echo "✅ dSYM structure verified for: $archive_path"
    return 0
}

# Verify dSYMs before creating XCFramework
echo "Verifying dSYM files..."
verify_dsym "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive"
verify_dsym "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive"

# Create XCFramework
echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -debug-symbols "$(pwd)/$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
    -framework "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -debug-symbols "$(pwd)/$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
    -output "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

# Create documentation archive
echo "Creating documentation archive for distribution..."
cd "$OUTPUT_DIR/Documentation"
zip -r "$FRAMEWORK_NAME.doccarchive.zip" "$FRAMEWORK_NAME.doccarchive"
cd - > /dev/null

# Copy Package.swift
echo "Copying Package.swift to output directory..."
cp "Package.swift" "$OUTPUT_DIR/"

# Final verification
if [ -d "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" ] && \
   [ -f "$OUTPUT_DIR/Package.swift" ] && \
   [ -d "$OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive" ]; then
    echo "✅ Successfully created:"
    echo "  - XCFramework at $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
    echo "  - Documentation at $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive"
    echo "  - Documentation archive at $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive.zip"
    echo "  - Package.swift at $OUTPUT_DIR/Package.swift"
else
    echo "❌ Failed to create complete package"
    exit 1
fi
