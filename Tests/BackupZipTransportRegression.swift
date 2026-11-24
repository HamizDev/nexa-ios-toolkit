import Foundation

// Tests the real orchestration with system zip/unzip on controlled fixtures only.
// Production uses the original WQFiles codec and CryptoKit verifier, not these commands.
@main
enum BackupZipTransportRegression {
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "BackupZipTransportRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do { try work() } catch { return }
        try require(false, message)
    }
    static func run(_ command: String, _ args: [String], cwd: URL? = nil) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/" + command)
        p.arguments = args
        p.currentDirectoryURL = cwd
        try p.run()
        p.waitUntilExit()
        try require(p.terminationStatus == 0, "Fixture ZIP command failed: " + command)
    }
    static func main() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("NexaZIP-" + UUID().uuidString)
        defer { try? fm.removeItem(at: temp) }
        let root = temp.appendingPathComponent("Backups", isDirectory: true)
        let archives = temp.appendingPathComponent("Archives", isDirectory: true)
        let source = root.appendingPathComponent("Original", isDirectory: true)
        let empty = source.appendingPathComponent("Payload/Empty", isDirectory: true)
        try fm.createDirectory(at: empty, withIntermediateDirectories: true)
        let bytes = Data("fixture".utf8)
        let raw = Data("{\"test\":1}".utf8)
        try bytes.write(to: source.appendingPathComponent("Payload/note.txt"))
        try raw.write(to: source.appendingPathComponent("manifest.json"))
        var checks = 0
        let verify: BackupZipTransport.Verify = { folder, parent in
            checks += 1
            let actual = try Data(contentsOf: folder.appendingPathComponent("Payload/note.txt"))
            let manifest = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
            try require(actual == bytes && manifest == raw, "Fixture verification failed")
            try require(folder.deletingLastPathComponent().path == parent.path, "Verifier root mismatch")
        }
        let write: BackupZipTransport.Write = { urls, zip in
            try run("zip", ["-q", "-r", zip.path] + urls.map(\.lastPathComponent), cwd: urls[0].deletingLastPathComponent())
        }
        let extract: BackupZipTransport.Extract = { zip, destination, limit in
            try require(limit == UInt64(BackupZipTransport.Limits.standard.expandedBytes), "Wrong extraction cap")
            try run("unzip", ["-q", zip.path, "-d", destination.path])
        }
        let archive = try BackupZipTransport.export(source, backupRoot: root, archiveRoot: archives, verify: verify, write: write, extract: extract)
        try require(checks == 2, "Export did not verify both copies")
        let imported = try BackupZipTransport.importZIP(archive, backupRoot: root, verify: verify, extract: extract)
        try require(checks == 3 && imported != source, "Import did not verify or reused source")
        try require(fm.fileExists(atPath: imported.appendingPathComponent("Payload/Empty").path), "Empty directory lost")
        let before = try fm.contentsOfDirectory(atPath: root.path).sorted()
        try rejects("Verifier failure published package") {
            _ = try BackupZipTransport.importZIP(archive, backupRoot: root, verify: { _, _ in throw BackupZipTransport.Failure.invalidPackage }, extract: extract)
        }
        try rejects("Unexpected extra file accepted") {
            _ = try BackupZipTransport.importZIP(archive, backupRoot: root, verify: verify, extract: { zip, dest, limit in
                try extract(zip, dest, limit)
                try Data().write(to: dest.appendingPathComponent("extra"))
            })
        }
        let after = try fm.contentsOfDirectory(atPath: root.path).sorted()
        try require(before == after, "Failed ZIP import leaked staging or published data")
        let previousArchives = try fm.contentsOfDirectory(atPath: archives.path).sorted()
        try rejects("Lost empty directory accepted on export") {
            _ = try BackupZipTransport.export(source, backupRoot: root, archiveRoot: archives, verify: verify, write: write, extract: { zip, dest, limit in
                try extract(zip, dest, limit)
                try fm.removeItem(at: dest.appendingPathComponent("Payload/Empty"))
            })
        }
        try rejects("Same-size modified payload accepted") {
            _ = try BackupZipTransport.export(source, backupRoot: root, archiveRoot: archives, verify: verify, write: write, extract: { zip, dest, limit in
                try extract(zip, dest, limit)
                try Data("changed".utf8).write(to: dest.appendingPathComponent("Payload/note.txt"))
            })
        }
        let currentArchives = try fm.contentsOfDirectory(atPath: archives.path).sorted()
        try require(previousArchives == currentArchives, "Failed ZIP export leaked staging or published data")
        let tiny = BackupZipTransport.Limits(expandedBytes: 1, archiveBytes: 1, entries: 1)
        try rejects("Archive size limit ignored") { _ = try BackupZipTransport.importZIP(archive, backupRoot: root, limits: tiny, verify: verify, extract: extract) }
        try rejects("Expanded size limit ignored") { _ = try BackupZipTransport.export(source, backupRoot: root, archiveRoot: archives, limits: tiny, verify: verify, write: write, extract: extract) }
        let link = temp.appendingPathComponent("link.zip")
        try fm.createSymbolicLink(at: link, withDestinationURL: archive)
        try rejects("Symbolic link archive accepted") { _ = try BackupZipTransport.importZIP(link, backupRoot: root, verify: verify, extract: extract) }
        try require(fm.fileExists(atPath: archive.path) && fm.fileExists(atPath: source.path), "Source data removed")
        print("PASS: ZIP round trip, empty directories, verification boundaries, tampering, failed-publication cleanup, limits and symlink rejection")
    }
}
