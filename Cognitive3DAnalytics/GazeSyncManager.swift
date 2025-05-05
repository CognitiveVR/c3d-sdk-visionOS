//
//  GazeSyncManager.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-02-21.
//

import Foundation

// MARK: - Protocol for gaze sync coordination
public protocol GazeSyncDelegate: AnyObject {
    /// Called when a gaze tick occurs, allowing synchronized recording of dynamic object states
    nonisolated func onGazeTick() async
}

/// The `GazeSyncManager` coordinates synchronization between gaze and dynamic object updates.
public class GazeSyncManager {
    private var delegates: [GazeSyncDelegate] = []
    private let logger = CognitiveLog(category: "GazeSyncManager")

    /// Add a delegate to receive gaze tick notifications
    public func addDelegate(_ delegate: GazeSyncDelegate) {
        logger.verbose("Adding gaze sync delegate")
        if !delegates.contains(where: { $0 === delegate }) {
            delegates.append(delegate)
            logger.verbose("Gaze delegate added successfully")
        } else {
            logger.verbose("Gaze delegate already exists")
        }
    }

    /// Remove a delegate from receiving gaze tick notifications
    public func removeDelegate(_ delegate: GazeSyncDelegate) {
        logger.verbose("Removing gaze sync delegate")
        delegates.removeAll(where: { $0 === delegate })
    }

    /// Notify all delegates of a gaze tick
    public func notifyGazeTick() async {
        logger.verbose("Notifying \(delegates.count) gaze sync delegates")

        // Create a local copy to avoid potential concurrent modification
        let currentDelegates = delegates
        for delegate in currentDelegates {
            await delegate.onGazeTick()
        }
    }
}
