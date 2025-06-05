//
//  CustomEvent.swift
//  Cognitive3DAnalytics
//
//  Copyright (c) 2024 Cognitive3D, Inc. All rights reserved.
//

import Foundation

/// Class to represent a custom event in the C3D SDK system.
public class CustomEvent {
    // MARK: - Properties

    ///  Name of the custom event.
    private let name: String

    /// Properties that get uploaded with an event.
    private var properties: [String: Any]

    /// Reference to core class to access SDK components
    private weak var core: Cognitive3DAnalyticsCore?

    /// Optional position associated with an event.
    /// The application developer can specify a positon when creating an event; if no position is specified, the HMD position is used.
    private var position: [Double]?

    /// Optional dynamic object identfier assoiated with an event.
    private var dynamicObjectId: String?

    /// Start time for the event.
    private let startTime: TimeInterval

    // MARK: - Initialization

    /// Initialize a custom event with a name and core reference
    /// - Parameters:
    ///   - name: Event name
    ///   - core: Cognitive3DAnalyticsCore instance
    internal init(name: String, core: Cognitive3DAnalyticsCore) {
        self.name = name
        self.properties = [:]
        self.core = core
        self.startTime = Date().timeIntervalSince1970
    }

    /// Initialize a custom event with a name, properties, and core reference
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Event properties
    ///   - core: Cognitive3DAnalyticsCore instance
    internal init(name: String, properties: [String: Any], core: Cognitive3DAnalyticsCore) {
        self.name = name
        self.properties = properties
        self.core = core
        self.startTime = Date().timeIntervalSince1970
    }

    /// Initialize a custom event with a name, dynamic object ID and core reference
    /// - Parameters:
    ///   - name: Event name
    ///   - dynamicObjectId: Optional ID of a dynamic object associated with this event
    ///   - core: Cognitive3DAnalyticsCore instance
    public init(name: String, dynamicObjectId: String? = nil, core: Cognitive3DAnalyticsCore) {
        self.name = name
        self.properties = [:]
        self.dynamicObjectId = dynamicObjectId
        self.core = core
        self.startTime = Date().timeIntervalSince1970
    }

    /// Initialize a custom event with a name, properties, dynamic object ID, and core reference
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Event properties
    ///   - dynamicObjectId: Optional ID of a dynamic object associated with this event
    ///   - core: Cognitive3DAnalyticsCore instance
    public init(name: String, properties: [String: Any], dynamicObjectId: String? = nil, core: Cognitive3DAnalyticsCore) {
        self.name = name
        self.properties = properties
        self.dynamicObjectId = dynamicObjectId
        self.core = core
        self.startTime = Date().timeIntervalSince1970
    }

    // MARK: - Public Methods

    /// Set the position for this event
    /// - Parameter position: 3D position [x, y, z]
    /// - Returns: Self for method chaining
    @discardableResult
    public func setPosition(_ position: [Double]) -> CustomEvent {
        self.position = position
        return self
    }

    /// Associate this event with a dynamic object
    /// - Parameter objectId: The ID of the dynamic object
    /// - Returns: Self for method chaining
    @discardableResult
    public func setDynamicObject(_ objectId: String) -> CustomEvent {
        self.dynamicObjectId = objectId
        return self
    }

    /// Set properties for this event
    /// - Parameter properties: Dictionary of properties
    /// - Returns: Self for method chaining
    @discardableResult
    public func setProperties(_ properties: [String: Any]) -> CustomEvent {
        for (key, value) in properties {
            self.properties[key] = value
        }
        return self
    }

    /// Set a single property for this event
    /// - Parameters:
    ///   - key: Property key
    ///   - value: Property value
    /// - Returns: Self for method chaining
    @discardableResult
    public func setProperty(key: String, value: Any) -> CustomEvent {
        self.properties[key] = value
        return self
    }

    /// Send this event (batched for network efficiency)
    /// - Parameter position: Optional position to use (overrides previously set position)
    /// - Returns: Success status
    @discardableResult
    public func send(_ position: [Double]? = nil) -> Bool {
        guard let core = core else { return false }

        let finalPosition = position ?? self.position ?? core.getCurrentHMDPosition()

        // Calculate duration and add as property if significant (>10ms)
        let duration = Date().timeIntervalSince1970 - startTime
        if duration > 0.01 {
            properties["duration"] = duration
        }

        // If we have a dynamic object ID, use recordDynamicCustomEvent method through core
        if let dynamicId = dynamicObjectId {
            return core.recordDynamicCustomEvent(
                name: name,
                position: finalPosition,
                properties: properties,
                dynamicObjectId: dynamicId,
                immediate: false
            )
        } else {
            // Otherwise use the standard method
            return core.recordCustomEvent(
                name: name,
                position: finalPosition,
                properties: properties,
                immediate: false
            )
        }
    }

    // MARK: - Deprecated Methods
    /// Send this event.
    /// Note: All events now use the batching system
    /// - Parameter position: Optional position to use (overrides previously set position)
    /// - Returns: Success status
    @available(*, deprecated, message: "Use sendWithHighPriority is functionally the same as using send() and will be removed in a future release")
    @discardableResult
    public func sendWithHighPriority(_ position: [Double]? = nil) -> Bool {
        return send(position)
    }

    /// Send this event immediately without batching
    /// - Parameter position: Optional position to use (overrides previously set position)
    /// - Returns: Success status
    @available(*, deprecated, message: "Use sendWithHighPriority instead for important events or send() for standard events")
    @discardableResult
    public func sendImmediate(_ position: [Double]? = nil) -> Bool {
        return sendWithHighPriority(position)
    }
}
