import Foundation

/// Synthetic local data only. Does not connect to WeChat's live container.
@main
struct NexaImportCombineHostTests {
    private static let fm = FileManager.default

    private static func assert(_ value: Bool, _ message: String) {
        precondition(value, "Import combine: " + message)
    }

    private static func fails(_ message: String, _ block: () throws -> Void) {
        var didFail = false
        do { try block() } catch { didFail = true }
        assert(didFail, message)
        print("PASS: rejected " + message)
    }

    private static func create(_ path: URL, bytes: [UInt8]) throws {
        try fm.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(bytes).write(to: path, options: .atomic)
    }

    private static func checkFile(_ path: URL, bytes: [UInt8]) throws {
        assert(try Data(contentsOf: path) == Data(bytes), "Unexpected bytes at " + path.path)
    }

    static func main() throws {
        guard let location = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              location.hasPrefix("/") else { fatalError("Fresh NEXA_TEST_ROOT required") }
        let temporary = URL(fileURLWithPath: location, isDirectory: true)
        assert(!fm.fileExists(atPath: temporary.path), "Test path already exists")
        defer { try? fm.removeItem(at: temporary) }

        let root = AppPaths.importFolder
        let from = root.appendingPathComponent("ImportedSource")
        let target = root.appendingPathComponent("ImportedTarget")
        try fm.createDirectory(at: from, withIntermediateDirectories: true)
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        try create(from.appendingPathComponent("Documents/common.dat"), bytes: [10, 11])
        try create(from.appendingPathComponent("Documents/new.dat"), bytes: [50])
        try create(target.appendingPathComponent("Documents/common.dat"), bytes: [1, 2])
        try create(target.appendingPathComponent("Documents/only-target.dat"), bytes: [99, 100])

        let merge = try NexaImportCombine.preview(
            source: from, target: target, mode: .merge
        )
        assert(merge.overlaps == 1 && merge.retainedTargetFiles == 1, "Merge preflight counts")
        assert(merge.expectedFiles.count == 3, "Merged file count")
        assert(merge.resultBytes == 5, "Merged byte count")

        let mergedReceipt = try NexaImportCombine.execute(merge)
        assert(mergedReceipt.state == .complete, "Merge journal")
        let merged = root.appendingPathComponent(mergedReceipt.resultName)
        try checkFile(merged.appendingPathComponent("Documents/common.dat"), bytes: [10, 11])
        try checkFile(merged.appendingPathComponent("Documents/new.dat"), bytes: [50])
        try checkFile(merged.appendingPathComponent("Documents/only-target.dat"), bytes: [99, 100])
        // A file-level conflict only selects source bytes in the new output.
        try checkFile(target.appendingPathComponent("Documents/common.dat"), bytes: [1, 2])
        try checkFile(from.appendingPathComponent("Documents/common.dat"), bytes: [10, 11])
        print("PASS: imported file-level merge retains extra target files without touching originals")

        let replace = try NexaImportCombine.preview(
            source: from, target: target, mode: .replace
        )
        assert(replace.expectedFiles.count == 2, "Replace manifest count")
        assert(replace.retainedTargetFiles == 0, "Replace excludes extra target file")
        let replacedReceipt = try NexaImportCombine.execute(replace)
        assert(replacedReceipt.state == .complete, "Replace journal")
        let replaced = root.appendingPathComponent(replacedReceipt.resultName)
        try checkFile(replaced.appendingPathComponent("Documents/common.dat"), bytes: [10, 11])
        assert(!fm.fileExists(atPath: replaced.appendingPathComponent("Documents/only-target.dat").path),
               "Extra target file unexpectedly copied into Replace result")
        try checkFile(target.appendingPathComponent("Documents/only-target.dat"), bytes: [99, 100])
        print("PASS: imported file-level replace excludes target extras but preserves target itself")

        let proposed = try NexaImportCombine.preview(
            source: from, target: target, mode: .merge
        )
        try create(from.appendingPathComponent("Documents/new.dat"), bytes: [88])
        fails("changed source after preview") {
            _ = try NexaImportCombine.execute(proposed)
        }
        try create(from.appendingPathComponent("Documents/new.dat"), bytes: [50])

        fails("same source and target") {
            _ = try NexaImportCombine.preview(source: from, target: from, mode: .merge)
        }
        let child = from.appendingPathComponent("Children")
        try fm.createDirectory(at: child, withIntermediateDirectories: true)
        fails("nested source and target") {
            _ = try NexaImportCombine.preview(source: from, target: child, mode: .merge)
        }
        fails("outside imports") {
            _ = try NexaImportCombine.preview(
                source: temporary, target: target, mode: .merge
            )
        }

        let external = temporary.appendingPathComponent("unselected-private.dat")
        try create(external, bytes: [254, 4])
        let link = from.appendingPathComponent("unsafe-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        fails("source contains symlink") {
            _ = try NexaImportCombine.preview(source: from, target: target, mode: .merge)
        }
        try fm.removeItem(at: link)
        let localAlias = root.appendingPathComponent("AliasedSource")
        try fm.createSymbolicLink(at: localAlias, withDestinationURL: from)
        fails("symlinked selected root even when target stays inside Imports") {
            _ = try NexaImportCombine.preview(
                source: localAlias, target: target, mode: .merge
            )
        }
        try fm.removeItem(at: localAlias)

        let conflictSource = root.appendingPathComponent("FileConflictSource")
        let conflictTarget = root.appendingPathComponent("FileConflictTarget")
        try fm.createDirectory(at: conflictSource, withIntermediateDirectories: true)
        try fm.createDirectory(at: conflictTarget, withIntermediateDirectories: true)
        try create(conflictSource.appendingPathComponent("Nested"), bytes: [7])
        try create(conflictTarget.appendingPathComponent("Nested/child"), bytes: [5])
        fails("file versus directory collision") {
            _ = try NexaImportCombine.preview(
                source: conflictSource, target: conflictTarget, mode: .merge
            )
        }

        // A pending receipt after a completed rename can be verified on reopen.
        let id = UUID()
        let clonedName = "NexaMerged-" + String(id.uuidString.prefix(8))
        let clonedPath = root.appendingPathComponent(clonedName)
        try fm.copyItem(at: merged, to: clonedPath)
        let journalDir = temporary.appendingPathComponent(
            "ApplicationSupport/Nexa/ImportCombinations"
        )
        try fm.createDirectory(at: journalDir, withIntermediateDirectories: true)
        func write(_ receipt: NexaImportCombine.Receipt) throws {
            try JSONEncoder().encode(receipt).write(
                to: journalDir.appendingPathComponent(receipt.id.uuidString + ".json"),
                options: .atomic
            )
        }
        let interrupted = NexaImportCombine.Receipt(
            id: id, createdAt: Date(), mode: .merge,
            sourceRelative: "ImportedSource", targetRelative: "ImportedTarget",
            resultName: clonedName, files: merge.expectedFiles, state: .pending
        )
        try write(interrupted)
        try NexaImportCombine.recoverPending()
        let recovered = try NexaImportCombine.receipts()
        assert(recovered.first(where: { $0.id == id })?.state == .complete,
               "Should verify a committed result from a pending journal")

        let unsafeId = UUID()
        try write(NexaImportCombine.Receipt(
            id: unsafeId, createdAt: Date(), mode: .merge,
            sourceRelative: "../../etc", targetRelative: "../../root",
            resultName: "../" + clonedName, files: merge.expectedFiles, state: .pending
        ))
        let absentId = UUID()
        try write(NexaImportCombine.Receipt(
            id: absentId, createdAt: Date(), mode: .replace,
            sourceRelative: "ImportedSource", targetRelative: "ImportedTarget",
            resultName: "NexaReplaced-" + String(absentId.uuidString.prefix(8)),
            files: replace.expectedFiles, state: .pending
        ))
        let symId = UUID()
        let symlinkResultName = "NexaMerged-" + String(symId.uuidString.prefix(8))
        try fm.createSymbolicLink(
            at: root.appendingPathComponent(symlinkResultName), withDestinationURL: merged
        )
        try write(NexaImportCombine.Receipt(
            id: symId, createdAt: Date(), mode: .merge,
            sourceRelative: "ImportedSource", targetRelative: "ImportedTarget",
            resultName: symlinkResultName, files: merge.expectedFiles, state: .pending
        ))
        try NexaImportCombine.recoverPending()
        let history = try NexaImportCombine.receipts()
        for invalid in [unsafeId, absentId, symId] {
            assert(history.first(where: { $0.id == invalid })?.state == .failed,
                   "Unsafe, absent or linked result was accepted")
        }
        try checkFile(target.appendingPathComponent("Documents/common.dat"), bytes: [1, 2])
        try checkFile(from.appendingPathComponent("Documents/new.dat"), bytes: [50])
        print("PASS: durable result recovery rejects corrupt paths, missing outputs and symlinks")
        print("PASS: Nexa imported snapshot merge/replace fixture suite")
    }
}
