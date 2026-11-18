import Foundation

// Disposable macOS regression fixtures for Nexa's user-imported data staging.
// No actual WeChat data and no external app containers are read or modified.
@main
struct NexaImportMigrationHostTests {
    private static let fm = FileManager.default

    private static func ensure(_ condition: Bool, _ name: String) {
        precondition(condition, "Migration fixture failed: " + name)
    }

    private static func rejects(_ name: String, _ operation: () throws -> Void) {
        var denied = false
        do { try operation() }
        catch { denied = true }
        ensure(denied, name)
        print("PASS: " + name)
    }

    private static func makeFile(_ url: URL, _ data: [UInt8]) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(data).write(to: url, options: .atomic)
    }

    static func main() throws {
        guard let name = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              name.hasPrefix("/") else {
            fatalError("NEXA_TEST_ROOT must name a disposable absolute path")
        }
        let root = URL(fileURLWithPath: name, isDirectory: true)
        ensure(!fm.fileExists(atPath: root.path), "fresh root")
        defer { try? fm.removeItem(at: root) }

        let imported = AppPaths.importFolder
        let source = imported.appendingPathComponent("ExportedWeChatData", isDirectory: true)
        let destination = imported.appendingPathComponent("LocalDestination", isDirectory: true)
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        try makeFile(source.appendingPathComponent("Documents/notes.db"), [0, 0, 1, 2, 254, 255])
        try makeFile(source.appendingPathComponent("Documents/avatar.bin"), [50, 51, 52])

        let folders = try NexaImportMigration.availableFolders()
        ensure(folders.count >= 3, "folder discovery")
        let preview = try NexaImportMigration.preview(source: source, destination: destination)
        ensure(preview.files.count == 2 && preview.totalBytes == 9, "file count and byte preflight")

        rejects("nested migration target refused") {
            _ = try NexaImportMigration.preview(
                source: source,
                destination: source.appendingPathComponent("Documents")
            )
        }
        rejects("out-of-scope destination refused") {
            _ = try NexaImportMigration.preview(source: source, destination: root)
        }

        // A plan must become invalid if the source changes between preview
        // and execution. No new destination is created in that case.
        try makeFile(source.appendingPathComponent("Documents/avatar.bin"), [0])
        rejects("changed source rejected") {
            _ = try NexaImportMigration.execute(preview)
        }
        ensure(try fm.contentsOfDirectory(atPath: destination.path).isEmpty,
               "failed transfer must not alter destination")
        try makeFile(source.appendingPathComponent("Documents/avatar.bin"), [50, 51, 52])

        // Following a symlink inside a user-imported folder would violate
        // the explicit imported-file boundary.
        let external = root.appendingPathComponent("private.bin")
        try makeFile(external, [4, 5])
        let link = source.appendingPathComponent("Documents/external-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        rejects("symlinked child rejected") {
            _ = try NexaImportMigration.preview(source: source, destination: destination)
        }
        try fm.removeItem(at: link)
        print("PASS: no writes after rejected preview")

        let valid = try NexaImportMigration.preview(source: source, destination: destination)
        let receipt = try NexaImportMigration.execute(valid)
        ensure(receipt.state == .complete && receipt.fileCount == 2, "completed receipt")
        let copied = destination.appendingPathComponent(receipt.finalFolderName)
        ensure(try Data(contentsOf: copied.appendingPathComponent("Documents/notes.db")) ==
               Data([0, 0, 1, 2, 254, 255]), "copied database bytes")
        ensure(try Data(contentsOf: copied.appendingPathComponent("Documents/avatar.bin")) ==
               Data([50, 51, 52]), "copied binary bytes")
        ensure(try Data(contentsOf: source.appendingPathComponent("Documents/notes.db")) ==
               Data([0, 0, 1, 2, 254, 255]), "original retained")
        ensure(try NexaImportMigration.receipts().contains(where: { $0.id == receipt.id }),
               "durable history record")
        print("PASS: staged, SHA-256 verified transfer with source preservation")

        // Reconstruct a journal for a simulated crash just after moving the
        // staged payload to the destination but before marking it complete.
        let interruptedID = UUID()
        let recoveredName = "NexaMigration-" + interruptedID.uuidString.prefix(8)
        let recoveredOutput = destination.appendingPathComponent(recoveredName)
        try fm.copyItem(at: source, to: recoveredOutput)
        let interrupted = NexaImportMigration.Receipt(
            id: interruptedID,
            created: Date(),
            source: "ExportedWeChatData",
            destination: "LocalDestination",
            finalFolderName: recoveredName,
            files: valid.files,
            state: .staging
        )
        let records = root.appendingPathComponent("ApplicationSupport/Nexa/ImportMigrations")
        try fm.createDirectory(at: records, withIntermediateDirectories: true)
        try JSONEncoder().encode(interrupted).write(
            to: records.appendingPathComponent(interruptedID.uuidString + ".json"),
            options: .atomic
        )
        try NexaImportMigration.recoverIfNeeded()
        let reopened = try NexaImportMigration.receipts()
        ensure(reopened.first(where: { $0.id == interruptedID })?.state == .complete,
               "verified interrupted commit recovered")

        let failedID = UUID()
        let absent = NexaImportMigration.Receipt(
            id: failedID,
            created: Date(),
            source: "ExportedWeChatData",
            destination: "LocalDestination",
            finalFolderName: "NexaMigration-Missing",
            files: valid.files,
            state: .staging
        )
        try JSONEncoder().encode(absent).write(
            to: records.appendingPathComponent(failedID.uuidString + ".json"),
            options: .atomic
        )
        try NexaImportMigration.recoverIfNeeded()
        ensure(try NexaImportMigration.receipts().first(where: { $0.id == failedID })?.state == .failed,
               "missing interrupted commit marked failed")
        print("PASS: recovery distinguishes complete and missing transactions")
        print("PASS: import migration host regression suite")
    }
}
