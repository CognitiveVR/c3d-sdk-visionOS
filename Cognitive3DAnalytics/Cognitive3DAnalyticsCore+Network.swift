//
//  Core3DAnalyticsCore_Network.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-03-10.
//

import Foundation
import UIKit

// MARK: - Network Connectivity and Offline Support
extension Cognitive3DAnalyticsCore {
    /// Initialize network connectivity monitoring and offline data handling
    public func setupConnectivitySupport() {
        // Initialize the network reachability monitor if not already initialized
        let _ = NetworkReachabilityMonitor.shared

        if ((config?.useSyncServices) != nil) {
            // Initialize the analytics sync service for offline data
            initializeAnalyticsSyncService()
        }

        // Register for app lifecycle notifications
        setupAppLifecycleObservers()

        logger?.info("Network connectivity monitoring initialized")
    }

    /// Initialize the analytics sync service
    private func initializeAnalyticsSyncService() {
        Task {
            await AnalyticsSyncService.shared.startNetworkMonitoring(core: self)
        }
    }

    /// Set up observers for app lifecycle events
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    /// Check current network connectivity status
    public func isNetworkConnected() -> Bool {
        return NetworkReachabilityMonitor.shared.isConnected
    }

    /// Get the current network connection type
    public func getNetworkConnectionType() -> String {
        return NetworkReachabilityMonitor.shared.connectionType.description
    }

    /// Manually trigger synchronization of any pending offline data
    public func syncOfflineData() {
        // Check if we've synced recently to avoid redundant syncs
        if let lastSync = lastSyncTime,
           Date().timeIntervalSince(lastSync) < minSyncInterval {
            logger?.info("Skipping sync - last sync was less than \(minSyncInterval) seconds ago")
            return
        }

        logger?.verbose("Manually triggering offline data sync")
        lastSyncTime = Date()
        triggerDataSync()
    }

    /// Trigger data sync for all cached data including exit polls
    private func triggerDataSync() {
        Task {
            if self.dataCacheSystem != nil {
                await AnalyticsSyncService.shared.triggerSync()
                self.logger?.verbose("Data sync triggered successfully")
            } else {
                self.logger?.warning("Cannot sync data: DataCacheSystem not initialized")
            }
        }
    }

    /// Send data with connectivity check, falling back to local storage if offline
    public func sendDataWithConnectivityCheck() async {
        if isNetworkConnected() {
            // We're online, send data normally
            await sendData()
        } else {
            // We're offline, no need to attempt sending
            logger?.info("Network unavailable, data will be queued for later transmission")
        }
    }

    /// Clean up network monitoring resources
    public func cleanupConnectivitySupport() {
        // Attempt to sync any remaining data before cleanup
        if isNetworkConnected() {
            syncOfflineData()
        }

        // Remove notification observers
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        // Stop network monitoring
        stopNetworkMonitoring()
    }

    /// Stop the network monitoring
    private func stopNetworkMonitoring() {
        Task {
            await AnalyticsSyncService.shared.stopNetworkMonitoring()
        }
    }

    // MARK: - App Lifecycle Methods

    /// Handle the app entering background
    @objc private func handleAppDidEnterBackground() {
        logger?.info("App did enter background - ensuring data is saved")

        // Try to sync any pending data when app goes to background
        if isNetworkConnected() {
            syncOfflineData()
        }
    }

    /// Handle the app entering foreground
    @objc private func handleAppWillEnterForeground() {
        logger?.info("App will enter foreground - checking for previous session data to post")

        // Check for pending data when app becomes active
        if isNetworkConnected() {
            syncOfflineData()
        }
    }

    /// Handle the app terminating
    @objc private func handleAppWillTerminate() {
        logger?.info("App will terminate - performing cleanup")

        cleanupConnectivitySupport()
    }

    // MARK: - error diagnosing
    // Helper function to determine if an error is network-related.
    // If the web request returns a response code 500 (backend error) or 0 (internet error), it is an network error.
    internal func isNetworkError(_ error: Error) -> Bool {
        logger?.info("Checking if error is network-related: \(error.localizedDescription)")

        // First check if this is an APIError.networkError wrapper
        if let apiError = error as? APIError {
            switch apiError {
            case .networkError(let underlyingError):
                // Extract the underlying error and check if it's a network error
                let nsError = underlyingError as NSError
                logger?.info("Found APIError.networkError with underlying error: \(nsError.domain), code: \(nsError.code)")

                if nsError.domain == NSURLErrorDomain {
                    let isNetworkIssue = [
                        NSURLErrorNotConnectedToInternet,
                        NSURLErrorNetworkConnectionLost,
                        NSURLErrorCannotConnectToHost,
                        NSURLErrorTimedOut,
                        NSURLErrorDNSLookupFailed,
                        NSURLErrorCannotFindHost,
                        NSURLErrorSecureConnectionFailed,
                        NSURLErrorDataNotAllowed
                    ].contains(nsError.code)

                    logger?.info("Underlying error is NSURLError with code \(nsError.code), is network error: \(isNetworkIssue)")
                    return isNetworkIssue
                }

                return false

            default:
                // For other API errors, they're not network related
                logger?.info("Error is APIError but not network-related: \(apiError)")
                return false
            }
        }

        // Direct check for NSURLErrorDomain errors (should be rare due to wrapping in NetworkAPIClient)
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            let networkErrorCodes = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorTimedOut,
                NSURLErrorDNSLookupFailed,
                NSURLErrorCannotFindHost,
                NSURLErrorSecureConnectionFailed,
                NSURLErrorDataNotAllowed
            ]

            let isNetworkError = networkErrorCodes.contains(nsError.code)
            logger?.info("Error is direct NSURLError with code \(nsError.code), is network error: \(isNetworkError)")
            return isNetworkError
        }

        logger?.info("Error is not in NSURLErrorDomain: \(nsError.domain)")
        return false
    }

}
