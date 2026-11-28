import Foundation
import Combine
import WatchConnectivity

// Public WatchConnectivity diagnostics only. A single retained delegate avoids
// competing session ownership when the Watch screen is opened more than once.
@MainActor
final class NexaWatchMonitor: NSObject, ObservableObject {
    static let shared = NexaWatchMonitor()

    @Published private(set) var status = NexaWatchStatus(activation: .notActivated)
    @Published private(set) var activationError: String?
    @Published private(set) var updatedAt: Date?

    private var activating = false

    private override init() {
        super.init()
        refresh()
    }

    func refresh(retry: Bool = false) {
        guard WCSession.isSupported() else {
            activationError = nil
            status = NexaWatchStatus(activation: .unavailable)
            updatedAt = Date()
            return
        }
        let session = WCSession.default
        if session.delegate !== self {
            session.delegate = self
            activating = false
        }
        if retry { activationError = nil }
        if session.activationState == .notActivated && !activating && activationError == nil {
            activating = true
            session.activate()
        }
        updateSnapshot()
    }

    private func updateSnapshot() {
        guard WCSession.isSupported() else {
            status = NexaWatchStatus(activation: .unavailable)
            updatedAt = Date()
            return
        }
        let session = WCSession.default
        let state: NexaWatchActivation
        switch session.activationState {
        case .notActivated: state = .notActivated
        case .inactive: state = .inactive
        case .activated: state = .activated
        @unknown default: state = .unknown
        }
        if state == .activated {
            activating = false
            activationError = nil
            status = NexaWatchStatus(activation: state, paired: session.isPaired,
                                     installed: session.isWatchAppInstalled, reachable: session.isReachable)
        } else {
            status = NexaWatchStatus(activation: state, activationFailed: activationError != nil)
        }
        updatedAt = Date()
    }
}

extension NexaWatchMonitor: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let message = error?.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activating = false
            self.activationError = message
            self.updateSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateSnapshot() }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.activating = false
            self.activationError = nil
            self.refresh()
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateSnapshot() }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.updateSnapshot() }
    }
}
