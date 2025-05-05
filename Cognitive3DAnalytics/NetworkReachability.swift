//
//  NetworkReachability.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2025-03-10.
//

import Foundation
import Network

// MARK: - NetworkReachabilityFramework
/// Framework-level code for network reachability monitoring
public class NetworkReachabilityMonitor {
    // MARK: - Public Properties
    public static let shared = NetworkReachabilityMonitor()

    public private(set) var isConnected: Bool = false
    public private(set) var connectionType: ConnectionType = .unavailable

    // MARK: - Connection Status Change Callback
    public typealias ConnectionStatusCallback = (Bool, ConnectionType) -> Void
    private var callbacks: [UUID: ConnectionStatusCallback] = [:]

    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.c3danalytics.networkmonitor", qos: .background)

    private let core = Cognitive3DAnalyticsCore.shared
    private let logger: CognitiveLog

    // MARK: - Connection Types
    public enum ConnectionType {
        case wifi
        case cellular
        case wired
        case other
        case unavailable

        public var description: String {
            switch self {
            case .wifi:
                return "WiFi"
            case .cellular:
                return "Cellular"
            case .wired:
                return "Wired"
            case .other:
                return "Other"
            case .unavailable:
                return "Unavailable"
            }
        }

        public var icon: String {
            switch self {
            case .wifi:
                return "wifi"
            case .cellular:
                return "antenna.radiowaves.left.and.right"
            case .wired:
                return "cable.connector"
            case .other:
                return "network"
            case .unavailable:
                return "wifi.slash"
            }
        }
    }

    // MARK: - Initialization
    private init() {
        logger = core.logger ?? CognitiveLog()

        // Set initial status without triggering callbacks
        let initialPath = monitor.currentPath
        updateNetworkStatus(initialPath, notifyCallbacks: false)

        // After initial status is set, set up the monitor for future updates
        setupMonitor()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Public Methods

    /// Add a callback to be notified when connection status changes
    /// - Parameter callback: The function to call when connection status changes
    /// - Returns: Token used to remove the callback
    @discardableResult
    public func addConnectionStatusCallback(_ callback: @escaping ConnectionStatusCallback) -> UUID {
        let id = UUID()
        callbacks[id] = callback

        // Immediately call the callback with current state
        DispatchQueue.main.async {
            callback(self.isConnected, self.connectionType)
        }

        return id
    }

    /// Remove a callback using the token returned from addConnectionStatusCallback
    /// - Parameter token: The token from addConnectionStatusCallback
    public func removeConnectionStatusCallback(token: UUID) {
        callbacks.removeValue(forKey: token)
    }

    /// Force a refresh of network status
    public func refreshNetworkStatus() {
        let path = monitor.currentPath
        updateNetworkStatus(path)
    }

    // MARK: - Private Methods
    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.updateNetworkStatus(path, notifyCallbacks: true)
        }

        monitor.start(queue: queue)
    }

    private func updateNetworkStatus(_ path: NWPath, notifyCallbacks: Bool = true) {
        let newIsConnected = path.status == .satisfied
        let newConnectionType = determineConnectionType(from: path)

        // Only update and notify if the status actually changed
        let statusChanged = (newIsConnected != isConnected || newConnectionType != connectionType)

        if statusChanged {
            logger.info("Network status changed: \(newIsConnected ? "Connected" : "Disconnected"), \(newConnectionType.description)")

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                self.isConnected = newIsConnected
                self.connectionType = newConnectionType

                // Only notify callbacks if instructed to do so
                if notifyCallbacks {
                    // Notify all registered callbacks
                    for callback in self.callbacks.values {
                        callback(newIsConnected, newConnectionType)
                    }
                }
            }
        }
    }

    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                return .wifi
            } else if path.usesInterfaceType(.cellular) {
                return .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                return .wired
            } else {
                return .other
            }
        } else {
            return .unavailable
        }
    }
}
