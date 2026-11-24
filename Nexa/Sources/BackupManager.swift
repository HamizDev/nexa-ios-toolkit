import Foundation
import CryptoKit

struct FileDigest: Codable, Equatable {
    let relativePath: String
    let byteCount: Int64
    let sha256: String
}

struct BackupManifest: Codable {
    let createdAt: Date
    let files: [FileDigest]
    let formatVersion: Int
    // Version 1 did not record directories, including empty ones.
    let directories: [String]?
}

struct BackupRecord: Identifiable {
    let folder: URL
    var id: String { folder.path }
    var name: String { folder.lastPathComponent }
}

enum BackupManager {
    enum BackupError: LocalizedError {
        case emptySource
        case symbolicLinkNotAllowed
        case invalidItem(String)
        case invalidManifest
        case unsupportedVersion(Int)
        case verificationFailed(String)

        var errorDescription: String? { message(in: "en") }

        func message(in language: String) -> String {
            let en = language == "en"
            switch self {
            case .emptySource:
                return en ? "Import at least one file or folder first." : "请先导入至少一个文件或文件夹。"
            case .symbolicLinkNotAllowed:
                return en ? "Symbolic links are not allowed in backups." : "备份不允许包含符号链接。"
            case .invalidItem(let path):
                return en ? "Invalid file or folder: \(path)" : "无效的文件或目录：\(path)"
            case .invalidManifest:
                return en ? "Invalid backup manifest." : "备份清单无效。"
            case .unsupportedVersion(let version):
                return en ? "Unsupported backup format: \(version)" : "不支持的备份格式：\(version)"
            case .verificationFailed(let path):
                return en ? "Verification failed: \(path)" : "完整性校验失败：\(path)"
            }
        }
    }

    private struct Inventory: Equatable {
        let files: [FileDigest]
        let directories: [String]
    }

    private static let manifestLimit = 32 * 1024 * 1024
    static var backupFolder: URL { AppPaths.backupFolder }

    static func listBackups() throws -> [BackupRecord] {
        let fm = FileManager.default
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        try requireDirectory(backupFolder)
        return try fm.contentsOfDirectory(
            at: backupFolder, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )
        .filter { url in
            guard let flags = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) else { return false }
            return flags.isDirectory == true && flags.isSymbolicLink != true
        }
        .sorted { $0.lastPathComponent > $1.lastPathComponent }
        .map { BackupRecord(folder: $0) }
    }

    static func createBackup(
        source: URL = AppPaths.importFolder,
        destinationRoot: URL = AppPaths.backupFolder,
        onProgress: ((BackupProgress) -> Void)? = nil
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try requireDirectory(source)
        let imports = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        guard !imports.isEmpty else { throw BackupError.emptySource }
        // Compare the copied data to the source inventory; never publish a partial backup.
        let expected = try inventory(in: source)
        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        try requireDirectory(destinationRoot)
        let token = UUID().uuidString
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = destinationRoot.appendingPathComponent(timestamp + "_" + token, isDirectory: true)
        let staging = destinationRoot.appendingPathComponent(".pending-" + token, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        let payload = staging.appendingPathComponent("Payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: false)
        // Retain WCMigrate's original progress model. This measures top-level items, not bytes.
        onProgress?(BackupProgress("copy", 0, imports.count, 0, fraction: 0))
        for (index, item) in imports.enumerated() {
            try fm.copyItem(at: item, to: payload.appendingPathComponent(item.lastPathComponent))
            onProgress?(BackupProgress("copy", index + 1, imports.count, 0,
                                       fraction: Double(index + 1) / Double(imports.count)))
        }
        guard try inventory(in: payload) == expected else {
            throw BackupError.verificationFailed("Source changed during backup")
        }
        let manifest = BackupManifest(createdAt: Date(), files: expected.files,
                                      formatVersion: 2, directories: expected.directories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        guard data.count <= manifestLimit else { throw BackupError.invalidManifest }
        try data.write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        try fm.moveItem(at: staging, to: folder)
        return folder
    }

    static func verify(_ folder: URL, backupRoot: URL = AppPaths.backupFolder) throws -> Int {
        try verifiedInventory(at: folder, backupRoot: backupRoot).files.count
    }

    // Restore a verified local backup to a unique new directory. Existing imports are never overwritten.
    static func restore(
        _ folder: URL,
        backupRoot: URL = AppPaths.backupFolder,
        destinationRoot: URL = AppPaths.importFolder
    ) throws -> URL {
        let fm = FileManager.default
        let expected = try verifiedInventory(at: folder, backupRoot: backupRoot)
        try fm.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        try requireDirectory(destinationRoot)
        let token = UUID().uuidString
        let output = destinationRoot.appendingPathComponent("Restored-" + token, isDirectory: true)
        // Stage beside Imports so an incomplete restoration never appears in the file browser.
        let staging = destinationRoot.deletingLastPathComponent()
            .appendingPathComponent(".restore-" + token, isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: folder.appendingPathComponent("Payload", isDirectory: true), to: staging)
        guard try inventory(in: staging) == expected else {
            throw BackupError.verificationFailed("Restored copy")
        }
        try fm.moveItem(at: staging, to: output)
        return output
    }

    private static func verifiedInventory(at folder: URL, backupRoot: URL) throws -> Inventory {
        try requireDirectory(backupRoot)
        guard folder.standardizedFileURL.deletingLastPathComponent().path == backupRoot.standardizedFileURL.path,
              !folder.lastPathComponent.hasPrefix(".") else {
            throw BackupError.invalidItem(folder.lastPathComponent)
        }
        try requireDirectory(folder)
        let manifestURL = folder.appendingPathComponent("manifest.json")
        let flags = try manifestURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard flags.isSymbolicLink != true, flags.isRegularFile == true,
              let size = flags.fileSize, size <= manifestLimit else { throw BackupError.invalidManifest }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.formatVersion == 1 || manifest.formatVersion == 2 else {
            throw BackupError.unsupportedVersion(manifest.formatVersion)
        }
        // Never construct paths from untrusted manifest strings or trap on duplicate dictionary keys.
        guard Set(manifest.files.map(\.relativePath)).count == manifest.files.count else {
            throw BackupError.invalidManifest
        }
        let current = try inventory(in: folder.appendingPathComponent("Payload", isDirectory: true))
        guard current.files == manifest.files.sorted(by: { $0.relativePath < $1.relativePath }) else {
            throw BackupError.verificationFailed("File names, lengths or SHA-256")
        }
        if manifest.formatVersion == 2 {
            guard let directories = manifest.directories,
                  Set(directories).count == directories.count,
                  current.directories == directories.sorted() else {
                throw BackupError.verificationFailed("Directory inventory")
            }
        }
        return current
    }

    private static func requireDirectory(_ url: URL) throws {
        let flags = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard flags.isSymbolicLink != true else { throw BackupError.symbolicLinkNotAllowed }
        guard flags.isDirectory == true else { throw BackupError.invalidItem(url.lastPathComponent) }
    }

    private static func inventory(in root: URL) throws -> Inventory {
        try requireDirectory(root)
        let fm = FileManager.default
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        var stack: [(url: URL, relative: String)] = [(root, "")]
        var files: [FileDigest] = []
        var directories: [String] = []
        // contentsOfDirectory throws on enumeration failure, rather than silently reporting an empty set.
        while let directory = stack.popLast() {
            for item in try fm.contentsOfDirectory(at: directory.url, includingPropertiesForKeys: Array(keys)) {
                let values = try item.resourceValues(forKeys: keys)
                let relative = directory.relative.isEmpty
                    ? item.lastPathComponent : directory.relative + "/" + item.lastPathComponent
                guard values.isSymbolicLink != true else { throw BackupError.symbolicLinkNotAllowed }
                if values.isDirectory == true {
                    directories.append(relative)
                    stack.append((item, relative))
                } else if values.isRegularFile == true {
                    let (length, hash) = try sha256(item)
                    guard let size = values.fileSize, Int64(size) == length else {
                        throw BackupError.verificationFailed(relative)
                    }
                    files.append(FileDigest(relativePath: relative, byteCount: length, sha256: hash))
                } else {
                    throw BackupError.invalidItem(relative)
                }
            }
        }
        return Inventory(files: files.sorted { $0.relativePath < $1.relativePath },
                         directories: directories.sorted())
    }

    private static func sha256(_ url: URL) throws -> (Int64, String) {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        var digest = SHA256()
        var length: Int64 = 0
        while let data = try reader.read(upToCount: 1024 * 1024), !data.isEmpty {
            length += Int64(data.count)
            digest.update(data: data)
        }
        return (length, digest.finalize().map { String(format: "%02x", $0) }.joined())
    }
}
