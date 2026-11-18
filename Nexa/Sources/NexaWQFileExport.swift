import Foundation

/// Original upstream WQFiles streaming file-copy API, scoped to a selected
/// read-only remote file and a fresh app-local destination.
/// No remote path is overwritten, deleted, or cached in permanent metadata.
enum NexaWQFileExport {
    enum Failure: LocalizedError {
        case invalidPath, unavailable, changedSource, copyFailed(String)
        var errorDescription: String? {
            switch self {
            case .invalidPath: return "The selected remote path is not an allowed container item."
            case .unavailable: return "The selected file is not a readable regular file."
            case .changedSource: return "The remote file changed while being copied. The local copy was discarded."
            case .copyFailed(let detail): return detail
            }
        }
    }

    static func copySelectedRemoteFile(_ remotePath: String) throws -> URL {
        guard NexaWQImportName.validRemotePath(remotePath) else {
            throw Failure.invalidPath
        }
        // Original WQFiles optimistic concurrency identity. A missing result
        // means the path cannot be safely treated as a regular file.
        guard let before = wq_file_version(remotePath) as NSDictionary? else {
            throw Failure.unavailable
        }

        let fm = FileManager.default
        try fm.createDirectory(at: AppPaths.importFolder, withIntermediateDirectories: true)
        let name = NexaWQImportName.importedFilename(
            remotePath: remotePath, transaction: UUID()
        )
        let target = AppPaths.importFolder.appendingPathComponent(name)
        guard !fm.fileExists(atPath: target.path) else { throw Failure.copyFailed("Local name collision.") }
        var reason: NSString?
        guard wq_copy_to_local(remotePath, target.path, &reason) else {
            try? fm.removeItem(at: target)
            throw Failure.copyFailed(reason as String? ?? "WQFiles source-to-local copy refused.")
        }
        guard let after = wq_file_version(remotePath) as NSDictionary?,
              before.isEqual(after) else {
            try? fm.removeItem(at: target)
            throw Failure.changedSource
        }
        // Ensure the post-copy file is regular and not a symlink before
        // allowing the ordinary Nexa file browser to show it.
        let flags = try target.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard flags.isRegularFile == true && flags.isSymbolicLink != true else {
            try? fm.removeItem(at: target)
            throw Failure.unavailable
        }
        return target
    }
}
