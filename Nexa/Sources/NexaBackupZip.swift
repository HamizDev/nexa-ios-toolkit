import Foundation

// Adapter to the pinned WQFiles source. No alternative ZIP engine is used in Nexa.
enum NexaBackupZip {
    struct CodecError: LocalizedError {
        let detail: String
        var errorDescription: String? { detail }
    }

    static func export(_ folder: URL, backupRoot: URL = AppPaths.backupFolder,
                       archiveRoot: URL = AppPaths.archiveFolder) throws -> URL {
        try BackupZipTransport.export(folder, backupRoot: backupRoot, archiveRoot: archiveRoot,
                                      verify: verify, write: write, extract: extract)
    }

    static func importZIP(_ zip: URL, backupRoot: URL = AppPaths.backupFolder) throws -> URL {
        try BackupZipTransport.importZIP(zip, backupRoot: backupRoot, verify: verify, extract: extract)
    }

    private static func verify(_ folder: URL, _ root: URL) throws {
        _ = try BackupManager.verify(folder, backupRoot: root)
    }

    private static func write(_ items: [URL], _ output: URL) throws {
        var skipped: UInt = 0
        var failure: NSString?
        let ok = wq_zip_write(items.map(\.path), output.path, wq_archive_posix_io(),
                              nil, nil, &skipped, &failure)
        guard ok else { throw CodecError(detail: failure as String? ?? "WQFiles ZIP writing failed.") }
        guard skipped == 0 else { throw BackupZipTransport.Failure.skippedEntries }
    }

    private static func extract(_ input: URL, _ output: URL, _ limit: UInt64) throws {
        var count: UInt = 0
        var skipped: UInt = 0
        var failure: NSString?
        let ok = wq_zip_extract(input.path, output.path, wq_archive_posix_io(),
                                limit, nil, nil, &count, &skipped, &failure)
        guard ok else { throw CodecError(detail: failure as String? ?? "WQFiles ZIP extraction failed.") }
        guard skipped == 0 else { throw BackupZipTransport.Failure.skippedEntries }
    }
}
