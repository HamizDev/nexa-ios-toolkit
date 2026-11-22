import Foundation

// macOS Foundation/CryptoKit host tests for Nexa's actual backup and
// journaled restore implementation. Never run these against real Documents.
// CI sets NEXA_TEST_ROOT to a newly created disposable directory.
@main
struct NexaRestoreHostTests {
    static let fm = FileManager.default

    static func require(_ condition: Bool, _ message: String) {
        precondition(condition, "TEST FAILURE: " + message)
    }

    static func expectError(_ name: String, _ operation: () throws -> Void) {
        var rejected = false
        do { try operation() }
        catch { rejected = true }
        require(rejected, name + " should reject invalid data")
    }

    static func createFile(_ url: URL, _ bytes: [UInt8]) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(bytes).write(to: url, options: .atomic)
    }

    static func journal(_ transaction: String, _ backupName: String) throws {
        let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"]!
        let file = URL(fileURLWithPath: root)
            .appendingPathComponent("ApplicationSupport/Nexa/restore-journal.json")
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode([
            "transaction": transaction,
            "backupName": backupName
        ])
        try data.write(to: file, options: .atomic)
    }

    static func main() throws {
        guard let env = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              !env.isEmpty, env.hasPrefix("/") else {
            fatalError("NEXA_TEST_ROOT must be an absolute, disposable test folder")
        }
        let root = URL(fileURLWithPath: env, isDirectory: true)
        require(!fm.fileExists(atPath: root.path), "Test root must start empty")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let imported = AppPaths.importFolder
        let first = imported.appendingPathComponent("nested/record.bin")
        let second = imported.appendingPathComponent("note.txt")
        try createFile(first, [0, 1, 2, 3, 254, 255])
        try createFile(second, Array("Original document".utf8))
        let emptyFolder = imported.appendingPathComponent("nested/empty-folder")
        try fm.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        let backup = try BackupManager.createBackup()
        require(try BackupManager.verify(backup) == 2, "Expected verified 2-file backup")
        print("PASS: backup and SHA-256 verification")

        let manifestData = try Data(contentsOf: backup.appendingPathComponent("manifest.json"))
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]
        require(manifest["formatVersion"] as? Int == 2, "new backups must use manifest v2")
        require((manifest["directories"] as? [String])?.contains("nested/empty-folder") == true,
                "v2 failed to record an empty folder")
        let withoutEmpty = AppPaths.backupFolder.appendingPathComponent("MissingEmptyDir")
        try fm.copyItem(at: backup, to: withoutEmpty)
        try fm.removeItem(at: withoutEmpty.appendingPathComponent("Payload/nested/empty-folder"))
        expectError("v2 detects missing empty folder") {
            _ = try BackupManager.verify(withoutEmpty)
        }
        let extraEmpty = AppPaths.backupFolder.appendingPathComponent("ExtraEmptyDir")
        try fm.copyItem(at: backup, to: extraEmpty)
        try fm.createDirectory(
            at: extraEmpty.appendingPathComponent("Payload/unexpected-empty"),
            withIntermediateDirectories: false
        )
        expectError("v2 detects unexpected empty folder") {
            _ = try BackupManager.verify(extraEmpty)
        }
        let legacy = AppPaths.backupFolder.appendingPathComponent("LegacyManifestV1")
        try fm.copyItem(at: backup, to: legacy)
        var oldManifest = manifest
        oldManifest["formatVersion"] = 1
        oldManifest.removeValue(forKey: "directories")
        try JSONSerialization.data(withJSONObject: oldManifest).write(
            to: legacy.appendingPathComponent("manifest.json"), options: .atomic
        )
        require(try BackupManager.verify(legacy) == 2, "legacy v1 backup compatibility broken")
        print("PASS: v2 includes empty directories and still accepts valid v1 backup manifests")

        // Force the copy to fail after the source snapshot was enumerated.
        // The partial backup must be cleaned up rather than listed as valid.
        let disappearing = imported.appendingPathComponent("disappearing.bin")
        try createFile(disappearing, [0xC1, 0xA7])
        let beforeFailure = try BackupManager.listBackups().map(\.name)
        expectError("incomplete backup is never published") {
            _ = try BackupManager.createBackup(onProgress: { progress in
                // The first callback precedes the very first copyItem.
                if progress.fraction == 0 { try? fm.removeItem(at: disappearing) }
            })
        }
        require(try BackupManager.listBackups().map(\.name) == beforeFailure,
                "failed backup became visible")
        require(try fm.contentsOfDirectory(atPath: AppPaths.backupFolder.path)
            .filter { $0.hasPrefix(".creating-") }.isEmpty,
                "failed backup left partial hidden staging")
        require(try Data(contentsOf: second) == Data("Original document".utf8),
                "failed backup changed unrelated source files")
        print("PASS: failed backup copy cleans up hidden staging without publication")

        let missingPayload = AppPaths.backupFolder.appendingPathComponent("MissingPayload")
        try fm.copyItem(at: backup, to: missingPayload)
        try fm.removeItem(at: missingPayload.appendingPathComponent("Payload"))
        expectError("missing backup payload rejected") {
            _ = try BackupManager.verify(missingPayload)
        }
        let linkedPayload = AppPaths.backupFolder.appendingPathComponent("LinkedPayload")
        try fm.copyItem(at: backup, to: linkedPayload)
        try fm.removeItem(at: linkedPayload.appendingPathComponent("Payload"))
        try fm.createSymbolicLink(
            at: linkedPayload.appendingPathComponent("Payload"),
            withDestinationURL: backup.appendingPathComponent("Payload")
        )
        expectError("symlinked backup payload rejected") {
            _ = try BackupManager.verify(linkedPayload)
        }
        let linkedManifest = AppPaths.backupFolder.appendingPathComponent("LinkedManifest")
        try fm.copyItem(at: backup, to: linkedManifest)
        try fm.removeItem(at: linkedManifest.appendingPathComponent("manifest.json"))
        try fm.createSymbolicLink(
            at: linkedManifest.appendingPathComponent("manifest.json"),
            withDestinationURL: backup.appendingPathComponent("manifest.json")
        )
        expectError("symlinked backup manifest rejected") {
            _ = try BackupManager.verify(linkedManifest)
        }
        let extraFile = AppPaths.backupFolder.appendingPathComponent("UnexpectedFile")
        try fm.copyItem(at: backup, to: extraFile)
        try createFile(extraFile.appendingPathComponent("unknown.dat"), [3, 5])
        expectError("unknown backup root entries rejected") {
            _ = try BackupManager.verify(extraFile)
        }
        let alias = AppPaths.backupFolder.appendingPathComponent("LinkedBackup")
        try fm.createSymbolicLink(at: alias, withDestinationURL: backup)
        require(try !BackupManager.listBackups().contains(where: { $0.folder == alias }),
                "symlinked backups should not be offered for restore")
        expectError("cannot restore a linked backup") {
            _ = try NexaBackupRestore.restore(from: alias)
        }
        print("PASS: backup structure validates manifest, payload and direct-child path")

        // Imported backup ZIPs are verified under a hidden same-volume
        // staging directory, then published under a visible final name.
        let incoming = AppPaths.backupFolder.appendingPathComponent(
            ".incoming-" + UUID().uuidString
        )
        try fm.copyItem(at: backup, to: incoming)
        require(try BackupManager.verify(incoming) == 2,
                "valid portable backup was rejected in hidden staging")
        require(try !BackupManager.listBackups().contains(where: {
            $0.folder.standardizedFileURL.path == incoming.standardizedFileURL.path
        }), "unfinished imported backup is visible in the UI")
        let finalImported = AppPaths.backupFolder.appendingPathComponent("Imported-Test")
        try fm.moveItem(at: incoming, to: finalImported)
        require(try BackupManager.verify(finalImported) == 2,
                "published imported backup failed verification")
        require(try BackupManager.listBackups().contains(where: {
            $0.folder.standardizedFileURL.path == finalImported.standardizedFileURL.path
        }), "completed imported backup was not listed")
        print("PASS: portable backup staging is hidden and publication is verified")

        let orphanRoot = AppPaths.documents.appendingPathComponent("PortableBackupStaging")
        let abandoned = orphanRoot.appendingPathComponent(UUID().uuidString)
        try createFile(abandoned.appendingPathComponent("Unpacked/junk.bin"), [0x42])
        let unrecognized = orphanRoot.appendingPathComponent("user-data")
        try createFile(unrecognized.appendingPathComponent("keep.bin"), [0xAB])
        let hiddenIncomplete = AppPaths.backupFolder.appendingPathComponent(
            ".incoming-" + UUID().uuidString
        )
        try createFile(hiddenIncomplete.appendingPathComponent("Payload/unfinished"), [0x3A])
        let symlinkedOrphan = orphanRoot.appendingPathComponent(UUID().uuidString)
        try fm.createSymbolicLink(at: symlinkedOrphan, withDestinationURL: unrecognized)
        require(try BackupManager.discardInterruptedPortableImports() == 2,
                "Expected exactly one abandoned import workspace and one incomplete backup")
        require(!fm.fileExists(atPath: abandoned.path), "Abandoned portable import was not cleaned")
        require(!fm.fileExists(atPath: hiddenIncomplete.path), "Incomplete backup not removed")
        require(try Data(contentsOf: unrecognized.appendingPathComponent("keep.bin")) ==
                    Data([0xAB]), "Unrecognized user data should not be deleted")
        require((try symlinkedOrphan.resourceValues(forKeys: [.isSymbolicLinkKey]))
                    .isSymbolicLink == true,
                "Orphan cleanup should skip linked roots")
        print("PASS: abandoned ZIP-import staging cleaned without touching unrelated data")

        let tampered = AppPaths.backupFolder.appendingPathComponent("Tampered")
        try fm.copyItem(at: backup, to: tampered)
        try createFile(tampered.appendingPathComponent("Payload/note.txt"), [99, 99])
        expectError("SHA-256 tamper detection") { _ = try BackupManager.verify(tampered) }

        let duplicate = AppPaths.backupFolder.appendingPathComponent("Duplicate")
        try fm.copyItem(at: backup, to: duplicate)
        let manifestURL = duplicate.appendingPathComponent("manifest.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as! [String: Any]
        var files = object["files"] as! [[String: Any]]
        files.append(files[0])
        object["files"] = files
        try JSONSerialization.data(withJSONObject: object).write(to: manifestURL, options: .atomic)
        expectError("duplicate manifest rejection") { _ = try BackupManager.verify(duplicate) }
        print("PASS: tampered and duplicate manifests rejected")

        let external = root.appendingPathComponent("external.txt")
        try createFile(external, [12])
        let link = imported.appendingPathComponent("unsafe-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: external)
        expectError("symlink detection") { _ = try BackupManager.createBackup() }
        try fm.removeItem(at: link)
        print("PASS: backup rejects symlinked inputs")

        // Restores the original two-file snapshot and retains the user's
        // previous changed imports in a separate private safety directory.
        try createFile(second, Array("Changed document".utf8))
        try createFile(imported.appendingPathComponent("unsaved.txt"), [77, 66])
        let result = try NexaBackupRestore.restore(from: backup)
        require(result.restoredFiles == 2, "Expected two restored files")
        require(try Data(contentsOf: second) == Data("Original document".utf8), "Restored content mismatch")
        require(fm.fileExists(atPath: result.priorImports.appendingPathComponent("unsaved.txt").path),
                "Previous files not retained")
        let retained = try NexaBackupRestore.listRecoveryCopies()
        require(retained.contains(where: {
            $0.kind == .previousImports
                && $0.folder.standardizedFileURL.path == result.priorImports.standardizedFileURL.path
        }), "Previous imports should remain discoverable after app restart")
        require(try NexaBackupRestore.validatedRecoveryCopy(result.priorImports)
                .standardizedFileURL.path == result.priorImports.standardizedFileURL.path,
                "Legitimate retained recovery data was rejected")
        require(try BackupManager.verifyFiles(in: imported, usingManifestAt: backup) == 2,
                "Restored imports do not match SHA-256 manifest")
        print("PASS: verified restore, independent staging and retained prior imports")

        expectError("reject out-of-scope restore URL") {
            _ = try NexaBackupRestore.restore(from: root)
        }

        let support = root.appendingPathComponent("ApplicationSupport/Nexa/RestoreSafety")
        try fm.createDirectory(at: support, withIntermediateDirectories: true)

        // Simulated kill after moving original Imports into RestoreSafety.
        try createFile(second, Array("Before interrupted restore".utf8))
        let interrupted = UUID().uuidString
        let safety1 = support.appendingPathComponent(interrupted)
        try fm.moveItem(at: imported, to: safety1)
        try journal(interrupted, backup.lastPathComponent)
        try NexaBackupRestore.recoverIfNeeded()
        require(try Data(contentsOf: second) == Data("Before interrupted restore".utf8),
                "Interrupted restore lost the original imports")
        print("PASS: interrupted rename is rolled back")

        // Simulated kill after staging was committed: keep verified Imports
        // and the pre-restore safety copy.
        let committed = UUID().uuidString
        let safety2 = support.appendingPathComponent(committed)
        try fm.moveItem(at: imported, to: safety2)
        try fm.copyItem(at: backup.appendingPathComponent("Payload"), to: imported)
        try journal(committed, backup.lastPathComponent)
        try NexaBackupRestore.recoverIfNeeded()
        require(try BackupManager.verifyFiles(in: imported, usingManifestAt: backup) == 2,
                "Completed transaction failed to recover")
        require(fm.fileExists(atPath: safety2.path), "Original recovery snapshot was discarded")
        print("PASS: interrupted post-commit recovery retains original snapshot")

        // A corrupt staged payload must be rejected in favor of the
        // previous Imports tree, rather than silently accepted.
        let broken = UUID().uuidString
        let safety3 = support.appendingPathComponent(broken)
        try fm.moveItem(at: imported, to: safety3)
        try createFile(imported.appendingPathComponent("note.txt"), [7, 8, 9])
        try journal(broken, backup.lastPathComponent)
        try NexaBackupRestore.recoverIfNeeded()
        require(try BackupManager.verifyFiles(in: imported, usingManifestAt: backup) == 2,
                "Corrupt staged data should have rolled back")
        let quarantined = root.appendingPathComponent(
            "Documents/RestoreStaging/rejected-" + broken
        )
        require(try Data(contentsOf: quarantined.appendingPathComponent("note.txt"))
                == Data([7, 8, 9]),
                "Rollback unexpectedly destroyed the rejected staged data")
        print("PASS: corrupt restore rolls back and preserves rejected data for inspection")

        let recoverable = try NexaBackupRestore.listRecoveryCopies()
        require(recoverable.contains(where: {
            $0.kind == .rejectedRestore
                && $0.folder.standardizedFileURL.path == quarantined.standardizedFileURL.path
        }), "Rejected payload should remain discoverable after relaunch")
        expectError("reject arbitrary recovery folder") {
            _ = try NexaBackupRestore.validatedRecoveryCopy(root)
        }
        let linkedRecovery = root.appendingPathComponent(
            "Documents/RestoreStaging/rejected-" + UUID().uuidString
        )
        try fm.createSymbolicLink(at: linkedRecovery, withDestinationURL: quarantined)
        expectError("reject linked recovery copy") {
            _ = try NexaBackupRestore.validatedRecoveryCopy(linkedRecovery)
        }
        let unsafeRoot = quarantined.appendingPathComponent("unsafe-link")
        try fm.createSymbolicLink(at: unsafeRoot, withDestinationURL: root)
        expectError("reject nested linked recovery contents") {
            _ = try NexaBackupRestore.validatedRecoveryCopy(quarantined)
        }
        try fm.removeItem(at: unsafeRoot)
        require(try !NexaBackupRestore.listRecoveryCopies().contains(where: {
            $0.id == linkedRecovery.standardizedFileURL.path
        }), "Symlink alias must not appear as a recoverable copy")
        print("PASS: recovery copies remain discoverable; linked and out-of-scope paths rejected")

        print("PASS: Nexa backup and restore host regression suite")
    }
}
