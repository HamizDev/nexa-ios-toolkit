import Foundation
import WatchConnectivity

// Nexa's one small adapter around the PINNED ORIGINAL HermesCompanion
// WatchConnectivityManager. The upstream class owns WCSession.default.delegate,
// backup file reception, SHA-256 history and transfer-to-Watch. Never create a
// competing iPhone-side WCSession delegate.
extension WatchConnectivityManager {
    func nexaPingWatch(_ onResult: @escaping @MainActor (String) -> Void) {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            onResult("Watch not reachable")
            return
        }
        WCSession.default.sendMessage(
            ["event": "nexa.ping", "version": "0.0.1"],
            replyHandler: { message in
                let status = message["status"] as? String ?? "Connected"
                Task { @MainActor in onResult(status) }
            },
            errorHandler: { error in
                let status = error.localizedDescription
                Task { @MainActor in onResult(status) }
            }
        )
    }

    // The NexaWatch dashboard can still ping iPhone while the original
    // Hermes companion receives asynchronous Watch backup files.
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message["event"] as? String == "nexa.ping" {
            replyHandler(["status": "Nexa iPhone 0.0.1", "event": "nexa.pong"])
        } else {
            replyHandler(["status": "Unsupported message"])
        }
    }
}
