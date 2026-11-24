import Foundation

@main
enum BackupPackageRegression {
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "BackupPackageRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do { try work() } catch { return }
        try require(false, message)
    }
    static func main() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("NexaPackages-" + UUID().uuidString)
        defer { try? fm.removeItem(at: temp) }
        let external = temp.appendingPathComponent("External", isDirectory: true)
        let payload = external.appendingPathComponent("Payload", isDirectory: true)
        let root = temp.appendingPathComponent("Backups", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let bytes = Data("fixture".utf8)
        let source = payload.appendingPathComponent("note.txt")
        try bytes.write(to: source)
        let file = FileDigest(relativePath: "note.txt", byteCount: Int64(bytes.count), sha256: "fixture-only")
        let manifest = BackupManifest(createdAt: Date(timeIntervalSince1970: 1000), files: [file], formatVersion: 2, directories: [])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let raw = try encoder.encode(manifest)
        let manifestURL = external.appendingPathComponent("manifest.json")
        try raw.write(to: manifestURL)
        // This Foundation-only fixture checks the verifier boundary and publication order, not SHA-256.
        var called = false
        let imported = try BackupPackageLibrary.importFolder(external, root: root) { candidate, staging in
            called = true
            let checked = try BackupPackageLibrary.checkedFolder(candidate, root: staging)
            let data = try Data(contentsOf: checked.appendingPathComponent("Payload/note.txt"))
            let listed = try BackupPackageLibrary.list(root: root)
            try require(data == bytes && listed.isEmpty, "Published before verification or changed bytes")
        }
        let records = try BackupPackageLibrary.list(root: root)
        try require(called && records.count == 1 && records[0].folder == imported, "Import not published")
        try require(records[0].manifest?.formatVersion == 2 && records[0].logicalBytes == Int64(bytes.count + raw.count), "Metadata or logical size incorrect")
        try require(BackupPackageLibrary.knownLogicalBytes(records) == records[0].logicalBytes, "Summary incorrect")
        try rejects("Verifier failure accepted") {
            _ = try BackupPackageLibrary.importFolder(external, root: root) { _, _ in throw BackupPackageLibrary.Failure.invalidPackage }
        }
        let afterFailure = try fm.contentsOfDirectory(atPath: root.path)
        try require(afterFailure.count == 1, "Failed import leaked staging or published data")
        let sourceBytes = try Data(contentsOf: source)
        try require(sourceBytes == bytes, "External source modified")
        try rejects("Outside library removed") { try BackupPackageLibrary.remove(external, root: root) }
        try rejects("Library root removed") { try BackupPackageLibrary.remove(root, root: root) }
        let link = root.appendingPathComponent("Link")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        try rejects("Symlink removed as package") { try BackupPackageLibrary.remove(link, root: root) }
        let nestedLink = payload.appendingPathComponent("link")
        try fm.createSymbolicLink(at: nestedLink, withDestinationURL: source)
        try rejects("Symlink package imported") { _ = try BackupPackageLibrary.importFolder(external, root: root) { _, _ in } }
        try fm.removeItem(at: nestedLink)
        let bad = BackupManifest(createdAt: manifest.createdAt, files: [file, file], formatVersion: 2, directories: [])
        try encoder.encode(bad).write(to: manifestURL)
        try rejects("Duplicate paths accepted") { _ = try BackupPackageLibrary.importFolder(external, root: root) { _, _ in } }
        try raw.write(to: manifestURL)
        let legacy = BackupManifest(createdAt: manifest.createdAt, files: [file], formatVersion: 1, directories: nil)
        try encoder.encode(legacy).write(to: manifestURL)
        let legacyRead = try BackupPackageLibrary.manifest(in: external)
        try require(legacyRead.formatVersion == 1, "Legacy manifest rejected")
        let unknown = BackupManifest(createdAt: manifest.createdAt, files: [file], formatVersion: 99, directories: nil)
        try encoder.encode(unknown).write(to: manifestURL)
        try rejects("Unknown version accepted") { _ = try BackupPackageLibrary.manifest(in: external) }
        try raw.write(to: manifestURL)
        try Data().write(to: external.appendingPathComponent("extra"))
        try rejects("Untracked package item accepted") { _ = try BackupPackageLibrary.manifest(in: external) }
        try fm.removeItem(at: imported.appendingPathComponent("manifest.json"))
        let damaged = try BackupPackageLibrary.list(root: root)
        try require(damaged.count == 1 && damaged[0].manifest == nil, "Damaged package not shown")
        try BackupPackageLibrary.remove(imported, root: root)
        let remaining = try BackupPackageLibrary.list(root: root)
        try require(remaining.isEmpty && fm.fileExists(atPath: source.path), "Deletion removed unrelated files")
        print("PASS: package metadata, logical sizes, pre-publication verification boundary, cleanup, v1 compatibility, malformed package rejection and scoped deletion")
    }
}
