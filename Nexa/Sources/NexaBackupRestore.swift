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
                        try? fm.removeItem(at: rejected)
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

        // The UI may only request restores from Nexa's own backup directory.
        let backup = selected.standardizedFileURL
        let trusted = AppPaths.backupFolder.standardizedFileURL
        guard backup.deletingLastPathComponent() == trusted,
              isValidName(backup.lastPathComponent),
              (try? backup.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false else {
            throw RestoreError.invalidBackup
        }

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
