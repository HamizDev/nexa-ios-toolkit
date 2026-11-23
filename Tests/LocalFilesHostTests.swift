import Foundation

/// Disposable macOS host coverage for the actual Nexa imported-file engine.
@main
struct NexaLocalFileHostTests {
    private static let fm = FileManager.default

    private static func check(_ condition: Bool, _ message: String) {
        precondition(condition, "NexaLocalFiles: " + message)
    }

    private static func rejects(_ message: String, _ operation: () throws -> Void) {
        do {
            try operation()
            fatalError("Expected rejection: " + message)
        } catch {
            print("PASS: rejected " + message)
        }
    }

    private static func put(_ data: [UInt8], at url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(data).write(to: url, options: .atomic)
    }

    static func main() throws {
        guard let input = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"],
              input.hasPrefix("/") else {
            fatalError("Set NEXA_TEST_ROOT to a new absolute disposable directory")
        }
        let root = URL(fileURLWithPath: input, isDirectory: true)
        check(!fm.fileExists(atPath: root.path), "test root already exists")
        try fm.createDirectory(at: AppPaths.importFolder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let importRoot = AppPaths.importFolder
        let nested = try NexaLocalFiles.createFolder(in: importRoot, name: "Documents")
        check(fm.fileExists(atPath: nested.path), "folder creation failed")
        rejects("unsafe folder name") {
            _ = try NexaLocalFiles.createFolder(in: importRoot, name: "../Backups")
        }
        rejects("hidden folder name") {
            _ = try NexaLocalFiles.createFolder(in: importRoot, name: ".private")
        }
        rejects("duplicate directory") {
            _ = try NexaLocalFiles.createFolder(in: importRoot, name: "Documents")
        }

        let original = nested.appendingPathComponent("notes.bin")
        try put([0, 1, 19, 253, 254, 255], at: original)
        let copy = try NexaLocalFiles.duplicate(original)
        check(copy.lastPathComponent == "notes copy.bin", "duplicate suffix")
        check(try Data(contentsOf: copy) == Data([0, 1, 19, 253, 254, 255]),
              "duplicated bytes mismatch")
        rejects("duplicate rename collision") {
            _ = try NexaLocalFiles.rename(original, to: "notes copy.bin")
        }

        let renamed = try NexaLocalFiles.rename(copy, to: "renamed.bin")
        check(!fm.fileExists(atPath: copy.path) && fm.fileExists(atPath: renamed.path),
              "rename was not atomic")
        let subset = try NexaLocalFiles.createFolder(in: nested, name: "Archive")
        let moved = try NexaLocalFiles.move(renamed, into: subset)
        check(moved.lastPathComponent == "renamed.bin", "file move failed")
        rejects("move folder into own descendant") {
            _ = try NexaLocalFiles.move(nested, into: subset)
        }
        let destinationOptions = try NexaLocalFiles.availableMoveFolders(for: original)
        let targetPath = subset.resolvingSymlinksInPath().standardizedFileURL.path
        let availablePaths = destinationOptions.map {
            $0.resolvingSymlinksInPath().standardizedFileURL.path
        }
        check(availablePaths.contains(targetPath),
              "move picker omitted \(targetPath); returned: \(availablePaths)")
        let folderOptions = try NexaLocalFiles.availableMoveFolders(for: nested)
        let folderPaths = folderOptions.map {
            $0.resolvingSymlinksInPath().standardizedFileURL.path
        }
        check(!folderPaths.contains(targetPath),
              "move picker exposed a descendant of source folder: \(folderPaths)")
        print("PASS: move destinations exclude own folder and descendants")
        rejects("move out of import sandbox") {
            _ = try NexaLocalFiles.move(original, into: root)
        }

        let outside = root.appendingPathComponent("Unselected.txt")
        try put([66, 77], at: outside)
        try NexaLocalFiles.validateUserImport(outside)
        rejects("rename external file") {
            _ = try NexaLocalFiles.rename(outside, to: "unsafe.txt")
        }

        // The ZIP gate shares the sandbox policy with local file operations.
        let archive = nested.appendingPathComponent("example.ZIP")
        try put([80, 75, 3, 4], at: archive)
        check(try NexaLocalFiles.validatedImportedZIP(archive) == archive,
              "valid imported ZIP should pass its input gate")
        rejects("ZIP outside Imports") {
            _ = try NexaLocalFiles.validatedImportedZIP(root.appendingPathComponent("external.zip"))
        }
        let linkedArchive = nested.appendingPathComponent("alias.zip")
        try fm.createSymbolicLink(at: linkedArchive, withDestinationURL: archive)
        rejects("symlinked ZIP inside Imports") {
            _ = try NexaLocalFiles.validatedImportedZIP(linkedArchive)
        }
        try fm.removeItem(at: linkedArchive)
        let fakeZip = try NexaLocalFiles.createFolder(in: nested, name: "fake.zip")
        rejects("ZIP filename that is actually a directory") {
            _ = try NexaLocalFiles.validatedImportedZIP(fakeZip)
        }
        print("PASS: ZIP extraction input gate rejects links, directories and outside files")

        check(try NexaLocalFiles.validatedImportedRegularFile(original) ==
              original.resolvingSymlinksInPath().standardizedFileURL,
              "Original WQFiles hex viewer must accept a regular imported file")
        rejects("WQ original viewer refuses external file") {
            _ = try NexaLocalFiles.validatedImportedRegularFile(outside)
        }
        rejects("WQ original viewer refuses folder") {
            _ = try NexaLocalFiles.validatedImportedRegularFile(fakeZip)
        }
        let hexAlias = nested.appendingPathComponent("hex-linked.bin")
        try fm.createSymbolicLink(at: hexAlias, withDestinationURL: original)
        rejects("WQ original viewer rejects internal symlink") {
            _ = try NexaLocalFiles.validatedImportedRegularFile(hexAlias)
        }
        try fm.removeItem(at: hexAlias)
        let parentAlias = importRoot.appendingPathComponent("hex-parent-symlink")
        try fm.createSymbolicLink(at: parentAlias, withDestinationURL: nested)
        rejects("WQ original viewer rejects symlinked ancestor") {
            _ = try NexaLocalFiles.validatedImportedRegularFile(
                parentAlias.appendingPathComponent(original.lastPathComponent)
            )
        }
        try fm.removeItem(at: parentAlias)
        print("PASS: WQFiles original hex viewer input gate rejects external and linked paths")

        // Imported copies are committed only after staging succeeds; no
        // security-scoped or other app container is touched by these fixtures.
        let importedCopy = try NexaLocalFiles.importSelected(outside)
        check(importedCopy.deletingLastPathComponent().standardizedFileURL ==
              importRoot.standardizedFileURL, "import escaped Nexa Imports")
        check(try Data(contentsOf: importedCopy) == Data([66, 77]),
              "imported bytes do not match source")
        let importedSecondCopy = try NexaLocalFiles.importSelected(outside)
        check(importedCopy != importedSecondCopy, "import should never overwrite")
        check(try Data(contentsOf: outside) == Data([66, 77]),
              "import changed original source")

        let providerFolder = root.appendingPathComponent("ProviderFolder")
        try put([17, 18], at: providerFolder.appendingPathComponent("Nested/notes.bin"))
        let importedFolder = try NexaLocalFiles.importSelected(providerFolder)
        check(try Data(contentsOf: importedFolder.appendingPathComponent("Nested/notes.bin"))
              == Data([17, 18]), "recursive import lost file data")
        let stagingRoot = AppPaths.documents.appendingPathComponent("ImportStaging")
        check((try fm.contentsOfDirectory(atPath: stagingRoot.path)).isEmpty,
              "staging directories were not cleaned after success")

        let maliciousFolder = root.appendingPathComponent("UnsafeProviderFolder")
        try fm.createDirectory(at: maliciousFolder, withIntermediateDirectories: true)
        try fm.createSymbolicLink(
            at: maliciousFolder.appendingPathComponent("private"),
            withDestinationURL: outside
        )
        rejects("import folder containing a symlink") {
            _ = try NexaLocalFiles.importSelected(maliciousFolder)
        }
        check((try fm.contentsOfDirectory(atPath: stagingRoot.path)).isEmpty,
              "failed import left staged partial data")
        print("PASS: staged imported files and folders preserve sources and clean up")

        check(try NexaLocalFiles.validatedArchiveFolder(nested)
              == nested.resolvingSymlinksInPath().standardizedFileURL,
              "safe imported folder must pass archive selection")
        rejects("archive folder outside Nexa Imports") {
            _ = try NexaLocalFiles.validatedArchiveFolder(providerFolder)
        }
        rejects("archive a regular file as a folder") {
            _ = try NexaLocalFiles.validatedArchiveFolder(importedCopy)
        }
        let linkedFolder = importRoot.appendingPathComponent("LinkedImportedFolder")
        try fm.createSymbolicLink(at: linkedFolder, withDestinationURL: nested)
        rejects("archive a symlinked imported directory") {
            _ = try NexaLocalFiles.validatedArchiveFolder(linkedFolder)
        }
        try fm.removeItem(at: linkedFolder)

        let orphan = stagingRoot.appendingPathComponent(UUID().uuidString)
        try put([91], at: orphan.appendingPathComponent("Payload"))
        let keep = stagingRoot.appendingPathComponent("keep-note.txt")
        try put([37], at: keep)
        let outsideAlias = stagingRoot.appendingPathComponent(UUID().uuidString)
        try fm.createSymbolicLink(at: outsideAlias, withDestinationURL: providerFolder)
        check(try NexaLocalFiles.discardInterruptedImports() == 1,
              "should remove exactly one abandoned import work directory")
        check(!fm.fileExists(atPath: orphan.path),
              "abandoned partial import was not discarded")
        check(try Data(contentsOf: keep) == Data([37]),
              "staging cleanup removed unrelated files")
        check(try Data(contentsOf: providerFolder.appendingPathComponent("Nested/notes.bin"))
              == Data([17, 18]), "cleanup followed a symlink outside staging")
        try fm.removeItem(at: outsideAlias)
        try fm.removeItem(at: keep)
        print("PASS: folder ZIP validation and interrupted-import cleanup")
        let externalLink = nested.appendingPathComponent("outside-link")
        try fm.createSymbolicLink(at: externalLink, withDestinationURL: outside)
        rejects("duplicate directory containing external symlink") {
            _ = try NexaLocalFiles.duplicate(nested)
        }
        rejects("read through symlink") {
            _ = try NexaLocalFiles.duplicate(externalLink)
        }
        rejects("security-scoped import does not accept symlinks") {
            try NexaLocalFiles.validateUserImport(externalLink)
        }
        try fm.removeItem(at: externalLink)
        print("PASS: paths, collisions, nested moves and symlink safety")

        let trashed = try NexaLocalFiles.trash(moved)
        check(!fm.fileExists(atPath: moved.path), "trash did not move source")
        check(try NexaLocalFiles.trashItems().contains(where: { $0.id == trashed.id }),
              "deleted file absent from trash")
        try put([88], at: moved)
        rejects("restore does not overwrite existing file") {
            _ = try NexaLocalFiles.restore(trashed)
        }
        check(try Data(contentsOf: moved) == Data([88]), "restored over an existing file")
        try fm.removeItem(at: moved)
        let restored = try NexaLocalFiles.restore(trashed)
        check(restored == moved, "restore path mismatch")
        check(try Data(contentsOf: restored) == Data([0, 1, 19, 253, 254, 255]),
              "restored bytes mismatch")
        check(try NexaLocalFiles.trashItems().isEmpty, "trash entry wasn't removed on restore")

        let permanentlyDeleted = try NexaLocalFiles.trash(restored)
        try NexaLocalFiles.permanentlyDelete(permanentlyDeleted)
        check(try NexaLocalFiles.trashItems().isEmpty, "permanent removal failed")
        check(!fm.fileExists(atPath: moved.path), "deleted payload was restored unexpectedly")
        let listed = try NexaLocalFiles.list(in: nested)
        check(listed.map { $0.resolvingSymlinksInPath().standardizedFileURL }
                  .contains(original.resolvingSymlinksInPath().standardizedFileURL),
              "nested listing lost original file")
        print("PASS: trash, collision-safe recovery, permanent removal and listing")
        print("PASS: complete NexaLocalFiles sandbox-only host regression")
    }
}
