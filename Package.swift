// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Cognitive3DAnalytics",
    platforms: [
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "Cognitive3DAnalytics",
            targets: ["Cognitive3DAnalytics"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        .binaryTarget(
            name: "Cognitive3DAnalytics",
            path: "Cognitive3DAnalytics.xcframework"
        )
    ]
)