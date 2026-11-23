import Foundation
import Combine
import WatchConnectivity

// iPhone-side WatchConnectivity diagnostic layer.
// The original Hermes Watch-side engine/views are compiled into NexaWatch.
// This phone-side monitor handles ping/status only; HermesCompanion's original
// WCSession backup transport, SHA-256 history and restore UI are NOT yet wired.
// A paired Watch is not evidence of a working cross-device backup/rollback.
@MainActor
final class NexaWatchMonitor: NSObject, ObservableObject {
    @Published private(set) var supported = false
    @Published private(set) var paired = false
    @Published private(set) var watchAppInstalled = false
    @Published private(set) var reachable = false
    @Published private(set) var activationState = "notActivated"
    @Published private(set) var pingResult: String?

    override init() {
        super.init()
        supported = WCSession.isSupported()
        guard supported else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refresh()
    }

    func pingWatch() {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            pingResult = "Watch not reachable"
            return
        }
        WCSession.default.sendMessage(
            ["event": "nexa.ping", "version": "0.0.1"],
            replyHandler: { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.pingResult = message["status"] as? String ?? "Connected"
                    self?.refresh()
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.pingResult = error.localizedDescription
                    self?.refresh()
                }
            }
        )
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
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(["status": "Nexa iPhone 0.0.1", "event": "nexa.pong"])
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

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
