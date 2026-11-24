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

    static func createImportedArchive(items selected: [URL]? = nil) throws -> Result {
        let root = AppPaths.importFolder
        let urls: [URL]
        if let selected { urls = selected }
        else { urls = try NexaFileLibrary.list(root: root).map(\.url) }
        guard !urls.isEmpty else { throw ZipError.nothingToArchive }
        let items = try NexaFileLibrary.selection(urls, root: root)
        for item in items { try NexaFileLibrary.validateTree(item.url) }
        let fm = FileManager.default
        let folder = AppPaths.archiveFolder
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try NexaFileLibrary.requireRoot(folder)
        let token = UUID().uuidString
        let zipURL = folder.appendingPathComponent("Nexa-" + token + ".zip")
        let staging = folder.appendingPathComponent(".pending-" + token + ".zip")
        defer { try? fm.removeItem(at: staging) }
        var skipped: UInt = 0
        var failure: NSString?
        let success = wq_zip_write(
            items.map { $0.url.path },
            staging.path,
            wq_archive_posix_io(),
            nil,
            nil,
            &skipped,
            &failure
        )
        guard success else {
            throw ZipError.failed(failure as String? ?? "WQFiles archive writer failed.")
        }
        try NexaLocalFiles.require(staging, directory: false)
        try fm.moveItem(at: staging, to: zipURL)
        return Result(file: zipURL, skipped: skipped)
    }

    static func extractImportedArchive(_ archive: URL) throws -> Result {
        let root = AppPaths.importFolder.standardizedFileURL
        let input = try NexaLocalFiles.checked(archive, inside: root)
        guard input.pathExtension.lowercased() == "zip" else { throw ZipError.notAnImportedFile }
        let fm = FileManager.default
        let token = UUID().uuidString
        let output = root.appendingPathComponent("Unpacked-" + token, isDirectory: true)
        let staging = root.deletingLastPathComponent().appendingPathComponent(".nexa-unpack-" + token, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            var extracted: UInt = 0
            var skipped: UInt = 0
            var failure: NSString?
            let ok = wq_zip_extract(
                input.path,
                staging.path,
                wq_archive_posix_io(),
                2 * 1024 * 1024 * 1024,
                nil,
                nil,
                &extracted,
                &skipped,
                &failure
            )
            guard ok else { throw ZipError.failed(failure as String? ?? "WQFiles ZIP extraction failed.") }
            try NexaFileLibrary.validateTree(staging)
            try fm.moveItem(at: staging, to: output)
            return Result(file: output, skipped: skipped)
        } catch {
            try? fm.removeItem(at: staging)
            throw error
        }
    }
}
