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
    #if DEBUG
    /// Only used by a disposable iOS Simulator smoke launch. Invokes the
    /// ORIGINAL Hermes backend, not a fake duplicate backup implementation.
    func nexaRunSyntheticBackupFixture() {
        enum SmokeFailure: LocalizedError {
            case failed(String)
            var errorDescription: String? {
                if case .failed(let detail) = self { return detail }
                return "Unknown fixture failure"
            }
        }

        let fm = FileManager.default
        let root = AppPaths.documents
        let marker = root.appendingPathComponent(".nexa-hermes-fixture-result")
        let source = root.appendingPathComponent("HermesSynthetic-" + UUID().uuidString + ".plist")
        let malformed = root.appendingPathComponent("HermesInvalid-" + UUID().uuidString + ".plist")
        defer {
            try? fm.removeItem(at: source)
            try? fm.removeItem(at: malformed)
        }

        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            try? fm.removeItem(at: marker)
            // A deliberately non-device, disposable plist with the two keys
            // the upstream Hermes iPhone receiver validates. No system data.
            let properties: [String: Any] = [
                "CacheData": Data([0x01, 0x02, 0x03, 0x04]),
                "CacheExtra": ["NexaSyntheticFixture": UUID().uuidString]
            ]
            let bytes = try PropertyListSerialization.data(
                fromPropertyList: properties, format: .binary, options: 0
            )
            try bytes.write(to: source, options: .atomic)
            let imported = try importBackup(from: source)
            guard case .imported(let record) = imported else {
                throw SmokeFailure.failed("First import was not accepted")
            }
            guard case .valid = verifyBackup(record) else {
                throw SmokeFailure.failed("Original Hermes hash verification failed")
            }
            guard let exported = exportURL(for: record),
                  try Data(contentsOf: exported) == bytes else {
                throw SmokeFailure.failed("Verified backup bytes differ after export")
            }
            guard case .duplicate = try importBackup(from: source) else {
                throw SmokeFailure.failed("Duplicate import was not rejected")
            }
            try Data("not a plist".utf8).write(to: malformed, options: .atomic)
            var invalidWasRejected = false
            do { _ = try importBackup(from: malformed) }
            catch { invalidWasRejected = true }
            guard invalidWasRejected else {
                throw SmokeFailure.failed("Malformed backup was incorrectly accepted")
            }
            loadBackupHistory()
            guard backups.contains(where: { $0.id == record.id }) else {
                throw SmokeFailure.failed("Imported backup disappeared after history reload")
            }
            try "PASS: original Hermes import, SHA-256, export, duplicate rejection, malformed input and history".write(
                to: marker, atomically: true, encoding: .utf8
            )
        } catch {
            try? ("FAIL: " + error.localizedDescription).write(
                to: marker, atomically: true, encoding: .utf8
            )
        }
    }
    #endif

}
