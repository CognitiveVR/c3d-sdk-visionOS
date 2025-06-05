//
//  AnalyticsSyncService.swift
//  Cognitive3D-Analytics-core
//
//  Created by Manjit Bedi on 2025-03-10.
//

import Foundation

/// The AnalyticsSyncService coordinates synchronization of the local data cache when network connectivity is available.
@MainActor
public class AnalyticsSyncService {
    public static let shared = AnalyticsSyncService()

    private let logger = CognitiveLog(category: "AnalyticsSyncService")
    private var networkMonitorToken: UUID?
    private var isInitializing = true

    private init() {
        // Private initializer to enforce singleton pattern
    }

    public func startNetworkMonitoring() {
        isInitializing = true

        // Add a callback to the network monitor
        networkMonitorToken = NetworkReachabilityMonitor.shared.addConnectionStatusCallback { [weak self] isConnected, connectionType in
            guard let self = self else { return }

            if isConnected {
                self.logger.info("Network is available, triggering sync to check for pending data")

                // Only trigger sync if not in initialization phase
                if !self.isInitializing {
                    // Directly call syncOfflineData without awaiting the result
                    Cognitive3DAnalyticsCore.shared.syncOfflineData()
                }
            } else {
                self.logger.verbose("Network is unavailable, will sync when connection returns")
            }
        }

        // Mark initialization as complete immediately after setting up
        isInitializing = false
        logger.verbose("local data cache & data sync: network monitoring started")
    }

    public func stopNetworkMonitoring() {
        if let token = networkMonitorToken {
            NetworkReachabilityMonitor.shared.removeConnectionStatusCallback(token: token)
            networkMonitorToken = nil
            logger.verbose("local data cache & data sync: network monitoring stopped")
        }
    }

    public func triggerSync() async {
        // Implement the actual sync logic
        if let dataCacheSystem = Cognitive3DAnalyticsCore.shared.dataCacheSystem {
            await dataCacheSystem.uploadCachedContent()
        }
    }
}
