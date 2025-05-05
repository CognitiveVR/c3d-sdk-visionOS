//
//  BatteryLevelRecorder.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-02-13.
//

import Foundation
import SwiftUI

/// Sensor recorder for the device battery charge level and state.
public class BatteryLevelRecorder {

    let batteryLevelSensor = "HMD Battery Level"
    let battertyStateSensor = "HMD Battery State"

    private let sensorRecorder: SensorRecorder

    var batteryLevel: Float = UIDevice.current.batteryLevel
    var batteryState: UIDevice.BatteryState = UIDevice.current.batteryState

    public init(sensorRecorder: SensorRecorder) {
        self.sensorRecorder = sensorRecorder
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateBatteryStatus), name: UIDevice.batteryLevelDidChangeNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateBatteryStatus), name: UIDevice.batteryStateDidChangeNotification,
            object: nil)
    }

    deinit {
        cleanUp()
    }

    private func cleanUp() {
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIDevice.batteryStateDidChangeNotification, object: nil)
        UIDevice.current.isBatteryMonitoringEnabled = false
    }

    internal func startTracking() {
#if targetEnvironment(simulator)
        batteryLevel = 1.0
        batteryState = .full
#endif

        updateBatteryStatus()
    }

    // This method is called to log the current battery levels when a analytics session is ending.
    internal func endSession() {
#if targetEnvironment(simulator)
        batteryLevel = 0.2
        batteryState = .charging
#endif
        updateBatteryStatus()
    }

    internal func stop() {
        cleanUp()
    }

    @objc private func updateBatteryStatus() {
#if !targetEnvironment(simulator)
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
#endif
        // Send a sensor recording.
        let converted = convertBatteryStateToUnity(batteryState: batteryState)
        sensorRecorder.recordDataPoint(name: batteryLevelSensor, value: Double(batteryLevel))
        sensorRecorder.recordDataPoint(name: battertyStateSensor, value: Double(converted))
    }

    /// Utility method, the C3D backend expects values to mapped to how Unity represents a battery's state.
    /// [Link](https://docs.unity3d.com/6000.0/Documentation/ScriptReference/BatteryStatus.html)
    func convertBatteryStateToUnity(batteryState: UIDevice.BatteryState) -> Int {
        switch batteryState {
        case .unknown: return 0
        case .unplugged: return 2
        case .charging: return 1
        case .full: return 4
        @unknown default:
            return 0
        }
    }
}
