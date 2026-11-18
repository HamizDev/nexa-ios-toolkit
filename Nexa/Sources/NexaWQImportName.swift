import Foundation

/// Pure validation and filename mapping for explicit WQFiles file exports.
/// The import name is always newly generated, never taken as a trusted path.
enum NexaWQImportName {
    private static let containerRoots = [
        "/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Shared/AppGroup",
        "/private/var/mobile/Containers/Shared/AppGroup"
    ]

    static func validRemotePath(_ input: String) -> Bool {
        guard input.hasPrefix("/"),
              !input.contains("\0"), !input.contains("\\"),
              input == input.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        let parts = input.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.first == "", parts.dropFirst().allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".."
        }) else { return false }
        return containerRoots.contains { input == $0 || input.hasPrefix($0 + "/") }
    }

    static func importedFilename(remotePath: String, transaction: UUID) -> String {
        let rawName = (remotePath as NSString).lastPathComponent
        var safe = ""
        var length = 0
        for ch in rawName {
            let normalized: Character =
                ch.isLetter || ch.isNumber ||
                ch == "." || ch == "-" || ch == "_" || ch == " " ? ch : "_"
            let bytes = String(normalized).utf8.count
            guard length + bytes <= 160 else { break }
            safe.append(normalized)
            length += bytes
        }
        safe = safe.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        if safe.isEmpty { safe = "imported-file" }
        return "WQ-" + String(transaction.uuidString.prefix(8)) + "-" + safe
    }
}
