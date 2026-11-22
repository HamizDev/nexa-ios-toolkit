import Foundation

/// Transactional restore of Nexa's own user-imported files.
///
/// Backups are authenticated against their SHA-256 manifest before and after
/// staging. Existing imports are moved to a retained recovery snapshot before
/// the staged replacement is committed. An on-disk journal allows the next
/// launch to repair a process interruption. This never touches other apps.
enum NexaBackupRestore {
    // Protect the journal from a background restore racing with another tab's
    // startup recovery. Recovery uses a nonblocking lock on the UI thread.
    private static let processLock = NSRecursiveLock()

    struct Result {
        let restoredFiles: Int
        let priorImports: URL
    }

    enum RestoreError: LocalizedError {
        case invalidBackup
        case invalidJournal
        case missingSnapshot

        var errorDescription: String? {
            switch self {
            case .invalidBackup:
                return "The selected backup is not a Nexa-managed backup."
            case .invalidJournal:
                return "An unrecognized restore journal requires manual recovery."
            case .missingSnapshot:
                return "Restore was interrupted, and its previous-files snapshot is missing."
            }
        }
    }

    private struct Journal: Codable {
        let transaction: String
        let backupName: String
    }

    private static var support: URL {
        #if NEXA_LOCAL_TEST
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Nexa", isDirectory: true)
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa", isDirectory: true)
    }
    private static var journalURL: URL {
        support.appendingPathComponent("restore-journal.json")
    }
    private static var safetyRoot: URL {
        support.appendingPathComponent("RestoreSafety", isDirectory: true)
    }
    private static var workingRoot: URL {
        AppPaths.documents.appendingPathComponent("RestoreStaging", isDirectory: true)
    }

    /// A recovery copy is raw, retained user data, NOT a verified backup.
    /// Previous imports and rejected post-crash payloads must remain accessible
    /// after app relaunch, without accidentally exposing arbitrary directories.
    struct RecoveryCopy: Identifiable {
        enum Kind { case previousImports, rejectedRestore }
        let folder: URL
        let kind: Kind
        var id: String { folder.standardizedFileURL.path }
    }

    static func validatedRecoveryCopy(_ selected: URL) throws -> URL {
        let fm = FileManager.default
        let candidate = selected.standardizedFileURL
        let parent = candidate.deletingLastPathComponent().path
        let name = candidate.lastPathComponent
        let isPrevious = parent == safetyRoot.standardizedFileURL.path
            && UUID(uuidString: name) != nil
        let isRejected = parent == workingRoot.standardizedFileURL.path
            && name.hasPrefix("rejected-")
            && UUID(uuidString: String(name.dropFirst("rejected-".count))) != nil
        guard isPrevious || isRejected else { throw RestoreError.invalidBackup }

        let parentFlags = try candidate.deletingLastPathComponent().resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        let flags = try candidate.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard parentFlags.isDirectory == true,
              parentFlags.isSymbolicLink != true,
              flags.isDirectory == true, flags.isSymbolicLink != true else {
            throw RestoreError.invalidBackup
        }
        guard let walker = fm.enumerator(at: candidate, includingPropertiesForKeys: [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
        ]) else { throw RestoreError.invalidBackup }
        while let item = walker.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
            ])
            guard values.isSymbolicLink != true,
                  values.isDirectory == true || values.isRegularFile == true else {
                throw RestoreError.invalidBackup
            }
        }
        return candidate
    }

    static func listRecoveryCopies() throws -> [RecoveryCopy] {
        let fm = FileManager.default
        var result: [RecoveryCopy] = []
        for (root, kind) in [
            (safetyRoot, RecoveryCopy.Kind.previousImports),
            (workingRoot, RecoveryCopy.Kind.rejectedRestore)
        ] {
            guard fm.fileExists(atPath: root.path) else { continue }
            let rootFlags = try root.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey
            ])
            guard rootFlags.isDirectory == true,
                  rootFlags.isSymbolicLink != true else {
                throw RestoreError.invalidBackup
            }
            let items = try fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            for item in items {
                guard (try? validatedRecoveryCopy(item)) != nil else { continue }
                result.append(RecoveryCopy(folder: item, kind: kind))
            }
        }
        return result.sorted { $0.folder.lastPathComponent > $1.folder.lastPathComponent }
    }

    private static func isValidName(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." &&
        !value.contains("/") && !value.contains("\\") &&
        !value.contains("\0")
    }

    private static func copyJournal(_ entry: Journal) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: support, withIntermediateDirectories: true)
        try JSONEncoder().encode(entry).write(to: journalURL, options: .atomic)
    }

    /// Called at startup and before all backup actions. Never delete a snapshot
    /// unless an explicit later retention policy is introduced.
    static func recoverIfNeeded() throws {
        guard processLock.lock(before: Date()) else { return }
        defer { processLock.unlock() }
        let fm = FileManager.default
        guard fm.fileExists(atPath: journalURL.path) else { return }

        let j = try JSONDecoder().decode(Journal.self, from: Data(contentsOf: journalURL))
        guard UUID(uuidString: j.transaction) != nil, isValidName(j.backupName) else {
            throw RestoreError.invalidJournal
        }

        let saved = safetyRoot.appendingPathComponent(j.transaction, isDirectory: true)
        let work = workingRoot.appendingPathComponent(j.transaction, isDirectory: true)
        let backup = AppPaths.backupFolder.appendingPathComponent(j.backupName, isDirectory: true)
        let imports = AppPaths.importFolder
        let snapshotExists = fm.fileExists(atPath: saved.path)
        let importsExist = fm.fileExists(atPath: imports.path)

        if snapshotExists {
            if importsExist {
                // A crash after the commit is safe to finish only when it still
                // matches the original verified backup. Otherwise roll back.
                if (try? BackupManager.verifyFiles(in: imports, usingManifestAt: backup)) == nil {
                    let rejected = workingRoot.appendingPathComponent("rejected-" + j.transaction)
                    try fm.createDirectory(at: workingRoot, withIntermediateDirectories: true)
                    try fm.moveItem(at: imports, to: rejected)
                    do {
                        try fm.moveItem(at: saved, to: imports)
                        // Never destroy a rejected post-crash payload. It may
                        // contain user edits made before recovery. Keep it in
                        // RestoreStaging/rejected-<transaction> for inspection.
                    } catch {
                        // Keep rejected files for manual recovery when rollback fails.
                        throw error
                    }
                }
            } else {
                try fm.moveItem(at: saved, to: imports)
            }
        } else if !importsExist {
            // A missing snapshot and missing original is never an acceptable
            // reason to create an empty folder and silently claim success.
            throw RestoreError.missingSnapshot
        }

        if fm.fileExists(atPath: work.path) { try? fm.removeItem(at: work) }
        try fm.removeItem(at: journalURL)
    }

    static func restore(from selected: URL) throws -> Result {
        processLock.lock()
        defer { processLock.unlock() }
        let fm = FileManager.default
        try recoverIfNeeded()

        // Share the same path, payload and manifest checks as backup export.
        let backup = try BackupManager.validatedBackupFolder(selected)
        let count = try BackupManager.verify(backup)
        let transaction = UUID().uuidString
        let working = workingRoot.appendingPathComponent(transaction, isDirectory: true)
        let stage = working.appendingPathComponent("Payload", isDirectory: true)
        let current = AppPaths.importFolder
        let safety = safetyRoot.appendingPathComponent(transaction, isDirectory: true)

        try fm.createDirectory(at: workingRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: safetyRoot, withIntermediateDirectories: true)
        try fm.createDirectory(at: working, withIntermediateDirectories: false)

        do {
            try fm.copyItem(at: backup.appendingPathComponent("Payload", isDirectory: true), to: stage)
            _ = try BackupManager.verifyFiles(in: stage, usingManifestAt: backup)
            try fm.createDirectory(at: current, withIntermediateDirectories: true)
            try copyJournal(Journal(transaction: transaction, backupName: backup.lastPathComponent))
            try fm.moveItem(at: current, to: safety)
            try fm.moveItem(at: stage, to: current)
            _ = try BackupManager.verifyFiles(in: current, usingManifestAt: backup)
            try fm.removeItem(at: journalURL)
            try? fm.removeItem(at: working)
            // Old files remain available inside Application Support/RestoreSafety.
            return Result(restoredFiles: count, priorImports: safety)
        } catch {
            // Re-run the durable recovery logic. If it fails, leave the journal
            // and both sets of files for the next app launch / manual recovery.
            if fm.fileExists(atPath: journalURL.path) {
                try? recoverIfNeeded()
            } else if fm.fileExists(atPath: working.path) {
                try? fm.removeItem(at: working)
            }
            throw error
        }
    }
}
