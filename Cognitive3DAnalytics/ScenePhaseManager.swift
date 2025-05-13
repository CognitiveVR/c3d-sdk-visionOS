//
//  ScenePhaseManager.swift
//  Cognitive3DAnalytics
//
//  Created by Manjit Bedi on 2025-02-26.
//

import Combine
import Foundation
import SwiftUI

/// The `ScenePhaseManager` class works with the `ScenePhase` to handle application state changes.
/// When the app changes to `inactive` or `background` state, it can end the current session subject to the current SDK settings.
/// See the followings settings in the ``Config`` class: `shouldSendDataOnInactive`, `shouldEndSessionOnBackground`.
/// This class works with `Combine`.
// TODO: review this module WRT to the use of Swift concurrency
public class ScenePhaseManager: ObservableObject {
    public static let shared = ScenePhaseManager()
    private weak var core = Cognitive3DAnalyticsCore.shared
    @Published public private(set) var currentScenePhase: ScenePhase = .inactive
    private var isProcessing = false  // Changed from @State to regular property
    private var cancellables = Set<AnyCancellable>()

    // A subject that external code can send scene phase updates to
    private let phaseSubject = PassthroughSubject<ScenePhase, Never>()

    private let eventSender: EventSender

    private init() {
        self.eventSender = EventSender(core: Cognitive3DAnalyticsCore.shared)
        // Subscribe to our own subject
        phaseSubject
            .sink { [weak self] newPhase in
                self?.processScenePhaseChange(newPhase)
            }
            .store(in: &cancellables)
    }

    public init(scenePhase: ScenePhase) {
        self.eventSender = EventSender(core: Cognitive3DAnalyticsCore.shared)
        self.currentScenePhase = scenePhase
    }

    /// Public method that apps can call to update the phase
    public func updateScenePhase(_ newPhase: ScenePhase) {
        phaseSubject.send(newPhase)
    }

    /// Internal method that handles `scenePhase` changes.
    private func processScenePhaseChange(_ newPhase: ScenePhase) {
        guard let core = self.core else {
            return
        }

        guard core.isSessionActive else {
            return
        }

        guard let config = core.config else {
            return
        }

        let appName = getAppDisplayName()
        currentScenePhase = newPhase

        let eventName: String
        switch newPhase {
        case .inactive:
            eventName = "\(appName): scene phase inactive"
            if config.shouldSendDataOnInactive {
                Task {
                    await core.sendData()
                }
            }

        case .active:
            eventName = "\(appName): scene phase active"

        case .background:
            eventName = "\(appName): scene phase background"
            if config.shouldEndSessionOnBackground {
                Task {
                    core.sessionState = .endedBackground
                    core.sessionDelegate?.sessionDidEnd(sessionId: core.sessionId, sessionState: .endedBackground)
                    _ = await core.endSession()
                }
            } else if !config.shouldSendDataOnInactive {
                Task {
                    await core.sendData()
                }
            }
        @unknown default:
            eventName = "\(appName): scene phase"
        }

        sendImmediateEvent(eventName: eventName)
    }

    private actor EventSender {
        private var isProcessing = false
        private weak var core: Cognitive3DAnalyticsCore?

        init(core: Cognitive3DAnalyticsCore?) {
            self.core = core
        }

        func sendEvent(eventName: String) async {
            guard !isProcessing else { return }
            isProcessing = true

            defer { isProcessing = false }

            let event = core.flatMap { core in
                CustomEvent(
                    name: eventName,
                    properties: [
                        "timestamp": Date().timeIntervalSince1970
                    ],
                    core: core
                )
            }

            let success = event?.sendWithHighPriority()
            if let logger = core?.logger {
                logger.info("custom event '\(eventName)' sent: \(success ?? false)")
            }
        }
    }

    private func sendImmediateEvent(eventName: String) {
        Task {
            await eventSender.sendEvent(eventName: eventName)
        }
    }
}

// MARK -

/// Code to use combine with the `ScenePhaseManager`
public struct ScenePhaseObserverModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    public func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) {
                let core = Cognitive3DAnalyticsCore.shared
                if let logger = core.logger {
                    logger.info("Scene phase changed to '\(scenePhase)'")
                }
                ScenePhaseManager.shared.updateScenePhase(scenePhase)
            }
    }
}

extension View {
    public func observeCognitive3DScenePhase() -> some View {
        self.modifier(ScenePhaseObserverModifier())
    }
}
