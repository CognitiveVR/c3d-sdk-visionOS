//
//  HmdHeight.swift
//  Cognitive3DAnalytics
//
//

import Combine
import Foundation

/// Class to estimate the HMD height by gathering position samples using the HMD position obtained from the `ARSessionManager`.
public class HmdHeight: NSObject, ARSessionDelegate {

    public static let shared = HmdHeight()

    private var heightSamples: [Double] = []
    private let maxSamples = 100
    /// Forehead height used in the height estimation; this is following the implementation in the Unity SDK.
    private let foreheadHeight = 0.11  // Metres

    #if DEBUG && DEBUG_HEIGHT_SAMPLES
        private var lastEsimatedHeight: Double = 0
    #endif

    private var isGatheringSamples = false

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        Cognitive3DAnalyticsCore.shared.sessionEventPublisher
            .sink { [weak self] event in
                switch event {
                case .started(let sessionId):
                    self?.sessionDidStart(sessionId: sessionId)
                case .ended(let sessionId, let state):
                    self?.sessionDidEnd(sessionId: sessionId, sessionState: state)
                }
            }
            .store(in: &cancellables)

        ARSessionManager.shared.addDelegate(self)
    }

    // Receives position updates from ARSessionManager
    @objc public func arSessionDidUpdatePosition(_ position: [Double]) {
        if isGatheringSamples {
            // Validate the position array has at least 2 elements (x, y, z)
            guard position.count > 1 else { return }
            let y = position[1]
            // Store the y (height) value
            heightSamples.append(y)
            // Keep only the latest maxSamples
            if heightSamples.count > maxSamples {
                heightSamples.removeFirst()
            }

            recordAndSendMedian()
        }
    }

    /// Get the median height from the samples taken so far.
    /// return the height in metres.
    public func medianHeightSample() -> Double? {
        guard !heightSamples.isEmpty else { return nil }
        let sorted = heightSamples.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0
            ? (sorted[mid - 1] + sorted[mid]) / 2.0
            : sorted[mid]
    }

    // Get the estimated height of the HMD with an adjustment for the forehead height.
    public func estimateUserHeight() -> Double? {
        guard let median = medianHeightSample() else { return nil }
        return median + foreheadHeight
    }

    public func clearHeightSamples() {
        heightSamples.removeAll()
    }

    public func heightInCentimeters() -> Double? {
        guard let meters = estimateUserHeight() else { return nil }
        return meters * 100
    }

    /// Record the estimated height - this will get sent to the C3D back end.
    public func recordAndSendMedian() {
        let analytics = Cognitive3DAnalyticsCore.shared
        let logger = analytics.logger

        // The height is being recorded in centimetres
        if let height = heightInCentimeters() {
            #if DEBUG && DEBUG_HEIGHT_SAMPLES
                if lastEsimatedHeight != height {
                    logger?.verbose("estimated HMD height is \(height)")
                    lastEsimatedHeight = height
                }
            #endif
            analytics.setParticipantProperty(keySuffix: "height", value: String(height))
        } else {
            logger?.warning("estimated HMD height unknown")
        }
    }

    // MARK: Session events
    public func sessionDidStart(sessionId: String) {
        // start sampling
        isGatheringSamples = true
    }

    public func sessionDidEnd(sessionId: String, sessionState: SessionState) {
        isGatheringSamples = false
        recordAndSendMedian()
    }
}
