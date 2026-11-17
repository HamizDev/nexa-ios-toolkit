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
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .nothingToArchive: return "There are no imported files to archive."
            case .notAnImportedFile: return "The ZIP must be a file imported into Nexa."
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

    static func createImportedArchive() throws -> Result {
        let items = try regularImportedItems()
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
            throw ZipError.failed(failure as String? ?? "WQFiles archive writer failed.")
        }
        return Result(file: zipURL, skipped: skipped)
    }

    static func extractImportedArchive(_ archive: URL) throws -> Result {
        let input = archive.standardizedFileURL
        let root = AppPaths.importFolder.standardizedFileURL
        guard input.path.hasPrefix(root.path + "/"), input.pathExtension.lowercased() == "zip" else {
            throw ZipError.notAnImportedFile
        }
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
