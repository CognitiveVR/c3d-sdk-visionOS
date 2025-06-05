#!/bin/bash

# build XCframework for the Swift C3D anaytics SDK

# Configuration
FRAMEWORK_NAME="Cognitive3DAnalytics"
SCHEME_NAME="$FRAMEWORK_NAME"
PROJECT_NAME="Cognitive3D-Analytics-core.xcodeproj"
OUTPUT_DIR="Build-Cognitive3DAnalytics"
DOCC_DIR="$FRAMEWORK_NAME.docc"

# Clean build directory
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/Documentation"

# Build for visionOS Device
echo "Building visionOS device archive..."
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS" \
    -archivePath "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ENABLE_PREVIEWS=YES \
    DOCC_HOSTING_BASE_PATH=$FRAMEWORK_NAME

# Build for visionOS Simulator
echo "Building visionOS simulator archive..."
xcodebuild archive \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS Simulator" \
    -archivePath "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive" \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    SKIP_INSTALL=NO \
    ENABLE_PREVIEWS=YES \
    DOCC_HOSTING_BASE_PATH=$FRAMEWORK_NAME

# Build DocC Documentation
echo "Building DocC documentation..."
xcodebuild docbuild \
    -scheme "$SCHEME_NAME" \
    -project "$PROJECT_NAME" \
    -destination "generic/platform=visionOS" \
    -derivedDataPath "$OUTPUT_DIR/DerivedData" \
    OTHER_DOCC_FLAGS="--transform-for-static-hosting --hosting-base-path $FRAMEWORK_NAME --output-path $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive"

# Create XCFramework
echo "Creating XCFramework..."
xcodebuild -create-xcframework \
    -framework "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -framework "$OUTPUT_DIR/archives/$FRAMEWORK_NAME-visionOS_Simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
    -output "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

# Create a zip of the documentation for distribution (optional)
echo "Creating documentation archive for distribution..."
cd "$OUTPUT_DIR/Documentation"
zip -r "$FRAMEWORK_NAME.doccarchive.zip" "$FRAMEWORK_NAME.doccarchive"
cd - > /dev/null

# Clean up temporary directories
rm -rf "$OUTPUT_DIR/archives"
rm -rf "$OUTPUT_DIR/DerivedData"

# Copy Package.swift to output directory
echo "Copying Package.swift to output directory..."
cp "Package.swift" "$OUTPUT_DIR/"

# Verify creation
if [ -d "$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework" ] && \
   [ -f "$OUTPUT_DIR/Package.swift" ] && \
   [ -d "$OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive" ]; then
    echo "✅ Successfully created:"
    echo "  - XCFramework at $OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
    echo "  - Documentation at $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive"
    echo "  - Documentation archive at $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive.zip"
    echo "  - Package.swift at $OUTPUT_DIR/Package.swift"
    echo ""
    echo "To view documentation:"
    echo "1. Double-click $OUTPUT_DIR/Documentation/$FRAMEWORK_NAME.doccarchive in Finder"
    echo "2. Documentation will open in Xcode's documentation viewer"
else
    echo "❌ Failed to create complete package"
    exit 1
fi
