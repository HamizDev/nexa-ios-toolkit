import Foundation

@main
struct NexaPlistHistoryHostTests {
    private static let fm = FileManager.default

    static func check(_ condition: Bool, _ reason: String) {
        precondition(condition, "Plist history failure: " + reason)
    }

    static func rejects(_ reason: String, _ operation: () throws -> Void) {
        var denied = false
        do { try operation() }
        catch { denied = true }
        check(denied, reason)
        print("PASS: " + reason)
    }

    static func plist(_ value: Int) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["Counter": value, "Enabled": true],
            format: .binary, options: 0
        )
    }

    static func main() throws {
        guard let p = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              p.hasPrefix("/") else { fatalError("Use a fresh absolute NEXA_TEST_ROOT") }
        let root = URL(fileURLWithPath: p, isDirectory: true)
        check(!fm.fileExists(atPath: root.path), "test root not empty")
        defer { try? fm.removeItem(at: root) }

        let folder = AppPaths.importFolder.appendingPathComponent("Preferences", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let item = folder.appendingPathComponent("ImportedCache.plist")
        let original = try plist(100)
        try original.write(to: item, options: .atomic)

        let first = try NexaPlistHistory.backup(file: item)
        check(first.byteCount == original.count, "snapshot byte count")
        check(try NexaPlistHistory.versions(for: item).count == 1, "one historical version")
        print("PASS: initial plist snapshot and private history list")

        let updated = try plist(200)
        try updated.write(to: item, options: .atomic)
        _ = try NexaPlistHistory.restore(first, to: item)
        check(try Data(contentsOf: item) == original, "restored initial plist")
        let history = try NexaPlistHistory.versions(for: item)
        check(history.count == 2, "restore should preserve overwritten version")
        check(history.contains(where: { $0.sha256 != first.sha256 }), "redo snapshot missing")
        print("PASS: restoring a version preserves the previously edited copy")

        let old = history.first(where: { $0.id == first.id })!
        let path = try NexaPlistHistory.snapshotURL(old, for: item)
        try Data([12, 31, 0]).write(to: path, options: .atomic)
        rejects("corrupted snapshot rejected by SHA-256") {
            _ = try NexaPlistHistory.restore(first, to: item)
        }
        check(try Data(contentsOf: item) == original, "corruption mutated the current file")

        let unselected = root.appendingPathComponent("NonImported.plist")
        try original.write(to: unselected)
        rejects("other-directory plist refused") {
            _ = try NexaPlistHistory.backup(file: unselected)
        }
        let link = folder.appendingPathComponent("Linked.plist")
        try fm.createSymbolicLink(at: link, withDestinationURL: unselected)
        rejects("symlinked plist refused") {
            _ = try NexaPlistHistory.backup(file: link)
        }
        print("PASS: out-of-scope and symlink plist paths rejected")
        print("PASS: imported plist history and restore host regression")
    }
}
