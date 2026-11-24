import Foundation

@main
enum PlistHistoryRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw NSError(domain: "PlistHistoryRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do { try work() } catch { return }
        try require(false, message)
    }

    static func plist(_ value: String, format: PropertyListSerialization.PropertyListFormat = .xml) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: ["name": value], format: format, options: 0)
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("NexaPlistTests-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let imports = root.appendingPathComponent("Imports", isDirectory: true)
        let history = root.appendingPathComponent("History", isDirectory: true)
        let nested = imports.appendingPathComponent("Folder", isDirectory: true)
        try fm.createDirectory(at: nested, withIntermediateDirectories: true)
        let a = nested.appendingPathComponent("settings.plist")
        let b = imports.appendingPathComponent("settings.plist")
        let outside = root.appendingPathComponent("outside.plist")
        let v1 = try plist("first")
        let v2 = try plist("second", format: .binary)
        let v3 = try plist("third")
        for file in [a, b, outside] { try v1.write(to: file) }
        let store = NexaPlistHistory(importRoot: imports, historyRoot: history)
        let first = try store.replace(a, expected: v1, with: v2)
        let current = try store.read(a)
        let aRecords = try store.records(for: a)
        let bRecords = try store.records(for: b)
        try require(current == v2 && aRecords.count == 1 && bRecords.isEmpty, "History not isolated by path")
        try rejects("Stale edit accepted") { try store.replace(a, expected: v1, with: v3) }
        try rejects("Cross-file restore accepted") { try store.restore(first.id, to: b, expected: v1) }
        try rejects("Out-of-root edit accepted") { try store.replace(outside, expected: v1, with: v2) }
        let linked = imports.appendingPathComponent("linked.plist")
        try fm.createSymbolicLink(at: linked, withDestinationURL: outside)
        try rejects("Symbolic link accepted") { _ = try store.read(linked) }
        let linkedFolder = imports.appendingPathComponent("linked-folder")
        try fm.createSymbolicLink(at: linkedFolder, withDestinationURL: root)
        try rejects("Ancestor symbolic link accepted") { _ = try store.read(linkedFolder.appendingPathComponent("outside.plist")) }
        try rejects("Invalid plist accepted") { try store.replace(a, expected: v2, with: Data("bad".utf8)) }
        let undo = try store.restore(first.id, to: a, expected: v2)
        let restored = try store.read(a)
        try require(restored == v1 && undo.reason == .restore, "Original bytes were not restored")
        try store.restore(undo.id, to: a, expected: v1)
        let redone = try store.read(a)
        try require(redone == v2, "Restore did not preserve the preceding version")
        try rejects("No-op edit accepted") { try store.replace(a, expected: v2, with: v2) }
        let payload = history.appendingPathComponent(first.id.uuidString).appendingPathComponent("original.plist")
        try Data("truncated".utf8).write(to: payload)
        try rejects("Corrupt snapshot accepted") { try store.restore(first.id, to: a, expected: v2) }
        let final = try store.read(a)
        let other = try store.read(b)
        let outsideBytes = try Data(contentsOf: outside)
        let records = try store.records(for: a)
        try require(final == v2 && other == v1 && outsideBytes == v1 && records.count == 3, "Failed operation modified data or history")
        let big = imports.appendingPathComponent("large.plist")
        try Data(repeating: 0, count: NexaPlistHistory.sizeLimit + 1).write(to: big)
        try rejects("Oversized plist accepted") { _ = try store.read(big) }
        print("PASS: history isolation, stale edits, out-of-root paths, symlinks, invalid/oversized plists, byte-exact restore, redo, corrupt snapshots and no-op rejection")
    }
}
