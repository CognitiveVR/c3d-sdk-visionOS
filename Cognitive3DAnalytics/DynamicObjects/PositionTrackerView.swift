//
//  PositionTrackerView.swift
//  Cognitive3DAnalytics
//

import RealityKit
import SwiftUI

/// Display mode for the view position tracking
public enum ViewDisplayMode {
    /// Debug visible mode
    case debug
    /// Minimal mode - takes up very little space but still functions
    case minimal

    /// Note: When using `.hidden` display mode, the view will still take up space in a VStack or HStack layout.
    /// For truly hidden behavior without affecting layout, place the PositionTrackerView in a ZStack:
    /// ```
    /// ZStack {
    ///     YourMainContent()
    ///     PositionTrackerView(dynamicId: "id", displayMode: .hidden)
    /// }
    /// ```
    case hidden
}

/// This view is used to get the transform of a SwiftUI view using a GeometryReader3D.
/// It will then store the transform etc in a data model that gets used with the associated proxy dynamic object.
public struct PositionTrackerView: View {
    /// We have a need to convert from the Point coordinates to real world spatial coordinates in Metric thus requiring the following.
    @Environment(\.physicalMetrics) private var metricsConverter: PhysicalMetricsConverter

    /// The model is used to hold the view transform data: position, scale, rotation.
    @State private var viewModel = ViewPositionModel()

    /// Display mode for the tracker view
    public var displayMode: ViewDisplayMode = .debug

    /// data model that is used to bridge data to proxy dynamic objects in a RealityKit view.
    @Environment(ProxyDynamicObjectsModel.self) private var proxyModel

    /// A timer is used to peridoically get the current transform values from the view.
    /// The interval can be fairly large as a user is not likely going to be resizing a view's size or position that frequently.
    @State private var timer: Timer?
    let timeInterval = 1.0

    public var isVerboseDebug = false

    /// The id of the proxy dynamic object to associate with this view.
    public var dynamicId: String = ""

    public init(dynamicId: String, displayMode: ViewDisplayMode = .hidden) {
        self.dynamicId = dynamicId
        // Initialize the displayMode state property
        self.displayMode = displayMode
    }

    public var body: some View {
        GeometryReader3D { geometry in
            Group {
                switch displayMode {
                case .debug:
                    normalView(geometry: geometry)
                case .minimal:
                    minimalView(geometry: geometry)
                case .hidden:
                    hiddenView(geometry: geometry)
                }
            }
            .onAppear {
                // Store a reference to the window model for use by other views
                proxyModel.viewModels[dynamicId] = viewModel

                // Store the geometry in AppModel
                proxyModel.viewGeometries[dynamicId] = geometry

                // Initial update
                update(geometry)

                // Start tracking if not in normal mode
                if displayMode != .debug && timer == nil {
                    timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
                        update(geometry)
                    }
                }
            }
        }
        // Note: onAppear handler is inside the GeometryReader3D where geometry is available
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onGeometryChange(for: AffineTransform3D.self) {
            if let transform = $0.transform(in: .immersiveSpace) {
                return transform
            }
            return AffineTransform3D()  // Return identity transform if nil
        } action: { newValue in
            guard let windowModel = proxyModel.viewModels[dynamicId] else {
                return
            }

            // Save this transform in AppModel for use in immersive space
            windowModel.transform = newValue
        }
    }

    // Normal full-featured view
    private func normalView(geometry: GeometryProxy3D) -> some View {
        VStack {
            Text("Window Position Tracker")
                .font(.title)
                .padding(.bottom)

            ScrollView {
                Text(viewModel.debugInfo)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 400)
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(10)

            HStack {
                Button(action: {
                    update(geometry)
                }) {
                    Text("Log Position")
                }
                .buttonStyle(.bordered)

                Button {
                    if timer == nil {
                        // Start a timer to update
                        timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: true) { _ in
                            update(geometry)
                        }
                    } else {
                        // Stop the timer
                        timer?.invalidate()
                        timer = nil
                    }
                } label: {
                    Text(timer == nil ? "Start Tracking" : "Stop Tracking")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .padding()
    }

    // Minimal view - tiny but still visible
    private func minimalView(geometry: GeometryProxy3D) -> some View {
        VStack {
            Text("📍")
                .font(.system(size: 10))
                .padding(2)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
                .onTapGesture {
                    update(geometry)
                }
        }
        .frame(width: 16, height: 16)
    }

    /// Hidden view - completely invisible
    /// Note: when working a GeometryReader3D, the view still occupies space in space and 3 dimensions in a `ZStack`.
    private func hiddenView(geometry: GeometryProxy3D) -> some View {
        Color.clear
                .frame(width: 1, height: 1) // Minimal size to ensure it doesn't visually affect layout
            .allowsHitTesting(false)
            .accessibility(hidden: true)
    }

    /// Update the view data.
    private func update(_ geometry: GeometryProxy3D) {
        let coordSpace = NamedCoordinateSpace.immersiveSpace

        // Get transform in immersive space
        guard let transform = geometry.transform(in: coordSpace) else {
            return
        }

        // Extract translation (position)
        let position = SIMD3<Float>(
            Float(transform.translation.x),
            Float(transform.translation.y),
            Float(transform.translation.z)
        )

        // Extract rotation
        let quaternion = transform.rotation?.quaternion

        // Extract size
        let size = SIMD3<Float>(
            Float(geometry.size.width),
            Float(geometry.size.height),
            Float(geometry.size.depth)
        )

        // Create debug info
        let info = generateDebugInfo(
            transform: transform,
            position: position,
            quaternion: quaternion,
            size: size
        )

        // Update model with data from the transform
        viewModel.updateInfo(
            info,
            position: position,
            quaternion: quaternion,
            size: size
        )
    }

    /// Creates a debug string from the transform data.
    private func generateDebugInfo(
        transform: AffineTransform3D,
        position: SIMD3<Float>,
        quaternion: simd_quatd?,
        size: SIMD3<Float>
    ) -> String {

        guard let windowModel = proxyModel.viewModels.first?.value else {
            return ""
        }

        var info = "Window Position Data:\n\n"

        if isVerboseDebug {
            // Transform info (formatted for readability)
            info += "Transform: \(transform.formattedDescription())\n\n"
        }

        // Use the conversion method from the viewModel instead of the local one
        let posConverted = viewModel.convertPointsToMetric(position, using: metricsConverter)

        // Position info
        info += "Position: \(formatVector3D(position)) in immersive space \(formatVector3D(posConverted))\n"

        // Quaternion info
        if let quat = quaternion {
            info += "Quaternion: [\(quat.real), \(quat.imag.x), \(quat.imag.y), \(quat.imag.z)]\n"
        } else {
            info += "Quaternion: not available\n"
        }

        // Size info
        info += "Size: \(formatVector3D(size))\n"

        // Add size in meters for clarity
        let sizeInMeters = viewModel.convertSizeToMetric(size, using: metricsConverter)
        info += "Size in meters: \(formatVector3D(sizeInMeters))\n"

        if isVerboseDebug {
            // Add transform in immersive space info
            if let immersiveTransform = windowModel.transform {
                info += "\nImmersive Space Transform: \(immersiveTransform.formattedDescription())\n"
            }

            // Add timestamp
            info += "\nLast Update: \(Date().formatted())"
        }

        return info
    }
}

#Preview {
    VStack() {
        Text("debug")
            .padding(.top, 50)
        PositionTrackerView(dynamicId: "ABCD1234", displayMode: .debug)
            .environment(ProxyDynamicObjectsModel())
    }.glassBackgroundEffect()
}

#Preview {
    VStack() {
        Text("minimal")
            .padding(.top, 50)
        PositionTrackerView(dynamicId: "ABCD1234", displayMode: .minimal)
            .environment(ProxyDynamicObjectsModel())
        Divider()
        Text("Testing...")
            .padding(.bottom, 50)
    }.glassBackgroundEffect()
}

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
