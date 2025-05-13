//
//  DynamicDataManager_GazeSync.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-02-21.
//

import Foundation

// MARK: - ManifestEntry Extension
extension ManifestEntry {
    /// Whether this object should sync its updates with gaze tracking
    public var syncWithGaze: Bool {
        // Default implementation returns false, actual value should be set during object registration
        return false
    }
}

// MARK: - DynamicDataManager Extension
extension DynamicDataManager: GazeSyncDelegate {

    /// Set whether a dynamic object should sync with gaze updates
    public func setSyncWithGaze(id: String, enabled: Bool) {
        if enabled {
            syncedObjects.insert(id)
        } else {
            syncedObjects.remove(id)
        }
    }

    /// Check if a dynamic object is configured to sync with gaze
    public func isSyncedWithGaze(id: String) -> Bool {
        return syncedObjects.contains(id)
    }

    public func onGazeTick() async {
        let currentManifests = activeManifests
        let currentStates = lastStates
        let currentSyncedObjects = syncedObjects

        for (id, _) in currentManifests {
            if currentSyncedObjects.contains(id) { // Only update synced objects
                if let state = currentStates[id] {
                    gazeSyncUpdates[id, default: 0] += 1  // Move increment here
                    await recordDynamicObject(
                        id: id,
                        position: state.lastPosition,
                        rotation: state.lastRotation,
                        scale: state.lastScale,
                        positionThreshold: 0,
                        rotationThreshold: 0,
                        scaleThreshold: 0,
                        updateRate: 0,
                        properties: nil
                    )
                }
            }
        }
    }
}
