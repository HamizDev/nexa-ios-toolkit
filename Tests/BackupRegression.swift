import Foundation

// macOS command-line regression runner; uses disposable fixtures, never actual user imports.
@main
enum BackupRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw NSError(domain: "BackupRegression", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: message]) }
    }

    static func rejects(_ message: String, _ operation: () throws -> Void) throws {
        do { try operation() } catch { return }
        try require(false, message)
    }

    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("NexaTests-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let source = root.appendingPathComponent("Imports", isDirectory: true)
        let backups = root.appendingPathComponent("Backups", isDirectory: true)
        let empty = source.appendingPathComponent("Empty", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        let file = source.appendingPathComponent("note.txt")
        let original = Data("original".utf8)
        try original.write(to: file)
        let backup = try BackupManager.createBackup(source: source, destinationRoot: backups)
        let manifestURL = backup.appendingPathComponent("manifest.json")
        let manifest = try Data(contentsOf: manifestURL)
        let payload = backup.appendingPathComponent("Payload", isDirectory: true)
        let copied = payload.appendingPathComponent("note.txt")
        let count = try BackupManager.verify(backup, backupRoot: backups)
        try require(count == 1, "Clean backup did not verify")
        let restored = try BackupManager.restore(backup, backupRoot: backups, destinationRoot: source)
        try require(tryData(restored.appendingPathComponent("note.txt")) == original, "Restore bytes differ")
        try require(fm.fileExists(atPath: restored.appendingPathComponent("Empty").path), "Empty directory lost")
        try require(tryData(file) == original, "Existing source overwritten")
        let second = try BackupManager.restore(backup, backupRoot: backups, destinationRoot: source)
        try require(second != restored, "Restore path reused")
        print("PASS: round trip, empty directories, no overwrite")
        try Data("altered!".utf8).write(to: copied)
        try rejects("Tampered bytes accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        let before = try fm.contentsOfDirectory(atPath: source.path).sorted()
        try rejects("Tampered backup restored") {
            _ = try BackupManager.restore(backup, backupRoot: backups, destinationRoot: source)
        }
        let after = try fm.contentsOfDirectory(atPath: source.path).sorted()
        try require(before == after, "Failed restore published files")
        try original.write(to: copied)
        print("PASS: tamper detection and failed restore")
        let emptyCopy = payload.appendingPathComponent("Empty", isDirectory: true)
        try fm.removeItem(at: emptyCopy)
        try rejects("Missing directory accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        try fm.createDirectory(at: emptyCopy, withIntermediateDirectories: false)
        var json = try JSONSerialization.jsonObject(with: manifest) as! [String: Any]
        let entries = json["files"] as! [[String: Any]]
        json["files"] = entries + entries
        try JSONSerialization.data(withJSONObject: json).write(to: manifestURL)
        try rejects("Duplicate manifest path accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        try manifest.write(to: manifestURL)
        print("PASS: v2 directory integrity and duplicate rejection")
        json["files"] = entries
        json["formatVersion"] = 1
        json.removeValue(forKey: "directories")
        try JSONSerialization.data(withJSONObject: json).write(to: manifestURL)
        let legacy = try BackupManager.verify(backup, backupRoot: backups)
        try require(legacy == 1, "Legacy v1 backup rejected")
        json["formatVersion"] = 999
        try JSONSerialization.data(withJSONObject: json).write(to: manifestURL)
        try rejects("Unknown backup version accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        try manifest.write(to: manifestURL)
        print("PASS: legacy v1 and unknown version")
        let symlink = payload.appendingPathComponent("link")
        try fm.createSymbolicLink(at: symlink, withDestinationURL: file)
        try rejects("Symbolic link accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        try fm.removeItem(at: symlink)
        try fm.removeItem(at: payload)
        try rejects("Missing payload accepted") { _ = try BackupManager.verify(backup, backupRoot: backups) }
        print("PASS: symbolic links and missing payload")
        print("All backup regression fixtures passed.")
    }

    private static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }
}
