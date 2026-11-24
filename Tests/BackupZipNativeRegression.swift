import Foundation

// macOS integration fixture: actual WQFiles ObjC ZIP implementation and CryptoKit.
@main
enum BackupZipNativeRegression {
    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw NSError(domain: "BackupZipNativeRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do { try work() } catch { return }
        try require(false, message)
    }
    static func main() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("NexaNativeZIP-" + UUID().uuidString)
        defer { try? fm.removeItem(at: temp) }
        let source = temp.appendingPathComponent("Imports", isDirectory: true)
        let backups = temp.appendingPathComponent("Backups", isDirectory: true)
        let archives = temp.appendingPathComponent("Archives", isDirectory: true)
        try fm.createDirectory(at: source.appendingPathComponent("Empty", isDirectory: true), withIntermediateDirectories: true)
        let data = Data("original".utf8)
        try data.write(to: source.appendingPathComponent("note.txt"))
        let first = try BackupManager.createBackup(source: source, destinationRoot: backups)
        let zip = try NexaBackupZip.export(first, backupRoot: backups, archiveRoot: archives)
        let second = try NexaBackupZip.importZIP(zip, backupRoot: backups)
        let count = try BackupManager.verify(second, backupRoot: backups)
        let restored = try BackupManager.restore(second, backupRoot: backups, destinationRoot: source)
        let restoredData = try Data(contentsOf: restored.appendingPathComponent("note.txt"))
        try require(first != second && count == 1 && restoredData == data, "Native ZIP round trip failed")
        try require(fm.fileExists(atPath: restored.appendingPathComponent("Empty").path), "Empty folder missing")
        let originalManifest = try Data(contentsOf: first.appendingPathComponent("manifest.json"))
        let importedManifest = try Data(contentsOf: second.appendingPathComponent("manifest.json"))
        try require(originalManifest == importedManifest, "Manifest changed")
        let before = try fm.contentsOfDirectory(atPath: backups.path).sorted()
        let bad = temp.appendingPathComponent("not-an-archive.zip")
        try Data("invalid ZIP".utf8).write(to: bad)
        try rejects("Invalid ZIP imported") { _ = try NexaBackupZip.importZIP(bad, backupRoot: backups) }
        let after = try fm.contentsOfDirectory(atPath: backups.path).sorted()
        try require(before == after, "Failed import left staging")
        try Data("altered!".utf8).write(to: first.appendingPathComponent("Payload/note.txt"))
        let archivesBefore = try fm.contentsOfDirectory(atPath: archives.path).sorted()
        try rejects("Corrupted backup exported") { _ = try NexaBackupZip.export(first, backupRoot: backups, archiveRoot: archives) }
        let archivesAfter = try fm.contentsOfDirectory(atPath: archives.path).sorted()
        try require(archivesBefore == archivesAfter, "Failed export left archive")
        print("PASS: actual WQFiles ZIP and CryptoKit round trip, empty directories, invalid ZIP and corrupted backup rejection")
    }
}
