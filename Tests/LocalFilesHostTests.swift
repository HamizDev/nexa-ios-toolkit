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
        check(destinationOptions.contains(where: {
            $0.resolvingSymlinksInPath() == subset.resolvingSymlinksInPath()
        }), "move picker omitted a safe nested destination")
        let folderOptions = try NexaLocalFiles.availableMoveFolders(for: nested)
        check(!folderOptions.contains(where: {
            $0.resolvingSymlinksInPath() == subset.resolvingSymlinksInPath()
        }), "move picker exposed a descendant of source folder")
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
