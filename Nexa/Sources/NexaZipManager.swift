import Foundation

// Calls WQFiles' original C/Objective-C archive implementation.
// Only app-local imported files and app-private export folders are used.
enum NexaZipManager {
    struct Result {
        let file: URL
        let skipped: UInt
    }

    enum ZipError: LocalizedError {
        case nothingToArchive
        case notAnImportedFile
        case invalidPortableBackup
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .nothingToArchive: return "There are no imported files to archive."
            case .notAnImportedFile: return "The ZIP must be a file imported into Nexa."
            case .invalidPortableBackup: return "Select a regular portable Nexa backup ZIP with exactly one backup directory."
            case .failed(let message): return message
            }
        }
    }

    private static func regularImportedItems() throws -> [URL] {
        let fm = FileManager.default
        try fm.createDirectory(at: AppPaths.importFolder, withIntermediateDirectories: true)
        return try fm.contentsOfDirectory(
            at: AppPaths.importFolder,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]
        ).filter { url in
            guard let flags = try? url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey]) else {
                return false
            }
            return flags.isSymbolicLink != true && (flags.isDirectory == true || flags.isRegularFile == true)
        }
    }

    private static func writeImportedArchive(
        _ items: [URL], requireComplete: Bool = false
    ) throws -> Result {
        guard !items.isEmpty else { throw ZipError.nothingToArchive }
        let fm = FileManager.default
        let folder = AppPaths.documents.appendingPathComponent("Archives", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let zipURL = folder.appendingPathComponent("Nexa-" + UUID().uuidString + ".zip")
        var skipped: UInt = 0
        var failure: NSString?
        let success = wq_zip_write(
            items.map(\.path),
            zipURL.path,
            wq_archive_posix_io(),
            nil,
            nil,
            &skipped,
            &failure
        )
        guard success else {
            try? fm.removeItem(at: zipURL)
            throw ZipError.failed(failure as String? ?? "WQFiles archive writer failed.")
        }
        if requireComplete && skipped > 0 {
            try? fm.removeItem(at: zipURL)
            throw ZipError.failed("The ZIP skipped some files; the incomplete archive was discarded.")
        }
        return Result(file: zipURL, skipped: skipped)
    }

    static func createImportedArchive() throws -> Result {
        try writeImportedArchive(regularImportedItems())
    }

    /// Archive a selected user-imported folder, not the whole Nexa workspace.
    /// The original WQFiles writer handles actual ZIP serialization.
    static func createImportedFolderArchive(_ folder: URL) throws -> Result {
        let verified = try NexaLocalFiles.validatedArchiveFolder(folder)
        return try writeImportedArchive([verified])
    }

    /// Export a self-contained copy of a SHA-256-verified Nexa backup.
    /// The ZIP contains the original manifest.json and Payload folder.
    /// The pinned WQFiles ZIP writer is used, not a new archive implementation.
    static func createVerifiedBackupArchive(_ selected: URL) throws -> Result {
        let backup = try BackupManager.validatedBackupFolder(selected)
        _ = try BackupManager.verify(backup)
        let archive = try writeImportedArchive([backup], requireComplete: true)
        do {
            // Detect any modifications to the backup while ZIP was being built.
            _ = try BackupManager.verify(backup)
            return archive
        } catch {
            try? FileManager.default.removeItem(at: archive.file)
            throw error
        }
    }

    /// Archives a retained pre-restore or rejected data copy, without
    /// modifying its contents. These raw files have no backup SHA-256 manifest.
    static func createRecoveryCopyArchive(_ selected: URL) throws -> Result {
        let checked = try NexaBackupRestore.validatedRecoveryCopy(selected)
        let archive = try writeImportedArchive([checked], requireComplete: true)
        do {
            _ = try NexaBackupRestore.validatedRecoveryCopy(checked)
            return archive
        } catch {
            try? FileManager.default.removeItem(at: archive.file)
            throw error
        }
    }

    /// Import an explicitly selected portable Nexa backup ZIP, without
    /// restoring it to the current Files workspace. The source is read-only.
    /// The caller must keep security-scoped access alive until this returns.
    private static let portableImportLock = NSRecursiveLock()

    static func discardInterruptedPortableImports() throws -> Int {
        portableImportLock.lock()
        defer { portableImportLock.unlock() }
        return try BackupManager.discardInterruptedPortableImports()
    }

    static func importPortableBackup(_ archive: URL) throws -> URL {
        portableImportLock.lock()
        defer { portableImportLock.unlock() }
        // Clean only abandoned, UUID-named workspaces before creating a new one.
        _ = try BackupManager.discardInterruptedPortableImports()
        let fm = FileManager.default
        let input = archive.standardizedFileURL
        let info = try input.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey
        ])
        guard input.pathExtension.lowercased() == "zip",
              info.isRegularFile == true, info.isSymbolicLink != true else {
            throw ZipError.invalidPortableBackup
        }

        let stagingRoot = AppPaths.documents.appendingPathComponent(
            "PortableBackupStaging", isDirectory: true
        )
        try fm.createDirectory(at: stagingRoot, withIntermediateDirectories: true)
        let stageFlags = try stagingRoot.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        guard stageFlags.isDirectory == true,
              stageFlags.isSymbolicLink != true else {
            throw ZipError.invalidPortableBackup
        }

        let transaction = UUID().uuidString
        let working = stagingRoot.appendingPathComponent(transaction, isDirectory: true)
        let unpacked = working.appendingPathComponent("Unpacked", isDirectory: true)
        let incoming = AppPaths.backupFolder.appendingPathComponent(
            ".incoming-" + transaction, isDirectory: true
        )
        var ownsIncoming = false
        try fm.createDirectory(at: unpacked, withIntermediateDirectories: true)
        do {
            var extracted: UInt = 0
            var skipped: UInt = 0
            var failure: NSString?
            let validZip = wq_zip_extract(
                input.path,
                unpacked.path,
                wq_archive_posix_io(),
                2 * 1024 * 1024 * 1024,
                nil,
                nil,
                &extracted,
                &skipped,
                &failure
            )
            guard validZip, skipped == 0, extracted > 0 else {
                throw ZipError.failed(
                    failure as String? ?? "The backup ZIP is invalid, incomplete or contains skipped entries."
                )
            }

            let topLevel = try fm.contentsOfDirectory(
                at: unpacked,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard topLevel.count == 1, let selected = topLevel.first else {
                throw ZipError.invalidPortableBackup
            }
            let folderInfo = try selected.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey
            ])
            guard folderInfo.isDirectory == true,
                  folderInfo.isSymbolicLink != true else {
                throw ZipError.invalidPortableBackup
            }

            try fm.createDirectory(
                at: AppPaths.backupFolder, withIntermediateDirectories: true
            )
            guard !fm.fileExists(atPath: incoming.path) else {
                throw ZipError.invalidPortableBackup
            }
            try fm.moveItem(at: selected, to: incoming)
            ownsIncoming = true
            _ = try BackupManager.verify(incoming)

            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let final = AppPaths.backupFolder.appendingPathComponent(
                "Imported-" + timestamp + "-" + String(UUID().uuidString.prefix(8)),
                isDirectory: true
            )
            guard !fm.fileExists(atPath: final.path) else {
                throw ZipError.invalidPortableBackup
            }
            try fm.moveItem(at: incoming, to: final)
            ownsIncoming = false
            try? fm.removeItem(at: working)
            return final
        } catch {
            if ownsIncoming { try? fm.removeItem(at: incoming) }
            try? fm.removeItem(at: working)
            throw error
        }
    }

    static func extractImportedArchive(_ archive: URL) throws -> Result {
        // This rejects path traversal, symlinked ancestors and symlinked ZIPs,
        // not merely strings that happen to share the Imports path prefix.
        let input = try NexaLocalFiles.validatedImportedZIP(archive)
        let root = AppPaths.importFolder.standardizedFileURL
        let fm = FileManager.default
        let output = root.appendingPathComponent("Unpacked-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: output, withIntermediateDirectories: false)
        do {
            var extracted: UInt = 0
            var skipped: UInt = 0
            var failure: NSString?
            let ok = wq_zip_extract(
                input.path,
                output.path,
                wq_archive_posix_io(),
                2 * 1024 * 1024 * 1024,
                nil,
                nil,
                &extracted,
                &skipped,
                &failure
            )
            guard ok else { throw ZipError.failed(failure as String? ?? "WQFiles ZIP extraction failed.") }
            return Result(file: output, skipped: skipped)
        } catch {
            try? fm.removeItem(at: output)
            throw error
        }
    }
}
