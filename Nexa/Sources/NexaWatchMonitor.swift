import Foundation
import Combine
import WatchConnectivity

// iPhone-side WatchConnectivity diagnostic layer.
// The full HermesEnabler watchOS app remains a separate upstream target in the workspace.
// A paired Watch does NOT mean that its watch-face customization engine is integrated.
@MainActor
final class NexaWatchMonitor: NSObject, ObservableObject {
    @Published private(set) var supported = false
    @Published private(set) var paired = false
    @Published private(set) var watchAppInstalled = false
    @Published private(set) var reachable = false
    @Published private(set) var activationState = "notActivated"

    override init() {
        super.init()
        supported = WCSession.isSupported()
        guard supported else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refresh()
    }

    func refresh() {
        guard WCSession.isSupported() else {
            supported = false
            return
        }
        let session = WCSession.default
        supported = true
        paired = session.isPaired
        watchAppInstalled = session.isWatchAppInstalled
        reachable = session.isReachable
        switch session.activationState {
        case .notActivated: activationState = "notActivated"
        case .inactive: activationState = "inactive"
        case .activated: activationState = "activated"
        @unknown default: activationState = "unknown"
        }
    }
}

extension NexaWatchMonitor: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }
}
