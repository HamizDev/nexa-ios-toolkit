import Foundation
import CryptoKit

struct FileDigest: Codable {
    let relativePath: String
    let byteCount: Int64
    let sha256: String
}

struct BackupManifest: Codable {
    let createdAt: Date
    let files: [FileDigest]
    let formatVersion: Int
    // Introduced in version 2. Nil is accepted only for old v1 manifests.
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
        case verificationFailed(String)
        var errorDescription: String? {
            switch self {
            case .emptySource: return "请先在文件页导入至少一个文件或文件夹。"
            case .symbolicLinkNotAllowed: return "备份包含符号链接。为避免越界访问，已停止操作。"
            case .verificationFailed(let path): return "文件校验失败：\(path)"
            }
        }
    }

    static var backupFolder: URL { AppPaths.backupFolder }

    /// Restrict backup access to one direct child of Nexa's backup root.
    /// A valid archive always has exactly one manifest and one directory payload;
    /// symlink aliases and unexpected extra files are not trusted as backups.
    static func validatedBackupFolder(_ selected: URL) throws -> URL {
        let fm = FileManager.default
        let candidate = selected.standardizedFileURL
        let trusted = backupFolder.standardizedFileURL
        guard candidate.deletingLastPathComponent() == trusted,
              !candidate.lastPathComponent.isEmpty,
              candidate.lastPathComponent != ".",
              candidate.lastPathComponent != ".." else {
            throw BackupError.verificationFailed("备份不在 Nexa 专用目录内")
        }
        let properties = try candidate.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        guard properties.isDirectory == true,
              properties.isSymbolicLink != true else {
            throw BackupError.verificationFailed("备份目录无效或为符号链接")
        }
        let payload = candidate.appendingPathComponent("Payload", isDirectory: true)
        let manifest = candidate.appendingPathComponent("manifest.json")
        let payloadFlags = try payload.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        let manifestFlags = try manifest.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey
        ])
        guard payloadFlags.isDirectory == true,
              payloadFlags.isSymbolicLink != true,
              manifestFlags.isRegularFile == true,
              manifestFlags.isSymbolicLink != true else {
            throw BackupError.verificationFailed("备份结构无效或包含符号链接")
        }
        let names = try fm.contentsOfDirectory(at: candidate, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
        guard Set(names) == Set(["Payload", "manifest.json"]) else {
            throw BackupError.verificationFailed("备份目录包含未知项目")
        }
        return candidate
    }

    static func listBackups() throws -> [BackupRecord] {
        let fm = FileManager.default
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        return try fm.contentsOfDirectory(
            at: backupFolder,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
            .filter {
                // A renamed .incoming-* directory may retain Finder's hidden
                // metadata. Filter by the CURRENT path instead of relying on
                // FileManager's .skipsHiddenFiles resource-flag behavior.
                guard !$0.lastPathComponent.hasPrefix(".") else { return false }
                guard let flags = try? $0.resourceValues(forKeys: [
                    .isDirectoryKey, .isSymbolicLinkKey
                ]) else { return false }
                return flags.isDirectory == true && flags.isSymbolicLink != true
            }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { BackupRecord(folder: $0) }
    }

    /// Only discard UUID-named work directories from interrupted *portable ZIP
    /// imports*. Never touch completed backup directories or unrelated files.
    /// The caller serializes this with live import operations.
    static func discardInterruptedPortableImports() throws -> Int {
        let fm = FileManager.default
        let stagingRoot = AppPaths.documents.appendingPathComponent(
            "PortableBackupStaging", isDirectory: true
        )
        var removed = 0
        for (root, prefix) in [
            (stagingRoot, ""),
            (backupFolder, ".incoming-")
        ] {
            guard fm.fileExists(atPath: root.path) else { continue }
            let flags = try root.resourceValues(forKeys: [
                .isDirectoryKey, .isSymbolicLinkKey
            ])
            guard flags.isDirectory == true && flags.isSymbolicLink != true else {
                throw BackupError.verificationFailed("备份导入临时目录不安全")
            }
            for candidate in try fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            ) {
                let name = candidate.lastPathComponent
                guard name.hasPrefix(prefix),
                      UUID(uuidString: String(name.dropFirst(prefix.count))) != nil,
                      let entry = try? candidate.resourceValues(forKeys: [
                          .isDirectoryKey, .isSymbolicLinkKey
                      ]),
                      entry.isDirectory == true,
                      entry.isSymbolicLink != true else {
                    continue
                }
                try fm.removeItem(at: candidate)
                removed += 1
            }
        }
        return removed
    }

    static func createBackup(onProgress: ((BackupProgress) -> Void)? = nil) throws -> URL {
        let fm = FileManager.default
        let source = AppPaths.importFolder
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let imports = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        guard !imports.isEmpty else { throw BackupError.emptySource }
        try rejectSymlinks(in: source)
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        // Incomplete snapshots remain hidden from the backup picker. A
        // same-volume rename publishes the verified snapshot in one step.
        let transaction = UUID().uuidString
        let working = backupFolder.appendingPathComponent(
            ".creating-" + transaction, isDirectory: true
        )
        let label = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-") + "_" + transaction
        let published = backupFolder.appendingPathComponent(label, isDirectory: true)
        let payload = working.appendingPathComponent("Payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        do {
            // Progress counts completed top-level items (including directories),
            // not the bytes inside each directory.
            onProgress?(BackupProgress("copy", 0, imports.count, 0, fraction: 0))
            for (index, item) in imports.enumerated() {
                try fm.copyItem(at: item, to: payload.appendingPathComponent(item.lastPathComponent))
                onProgress?(BackupProgress("copy", index + 1, imports.count, 0,
                                           fraction: Double(index + 1) / Double(imports.count)))
            }
            let manifest = BackupManifest(
                createdAt: Date(),
                files: try digests(in: payload),
                formatVersion: 2,
                directories: try directoryPaths(in: payload)
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(manifest).write(
                to: working.appendingPathComponent("manifest.json"), options: .atomic
            )
            // Keep a partial or unverifiable backup out of the visible list.
            _ = try verify(working)
            guard !fm.fileExists(atPath: published.path) else {
                throw BackupError.verificationFailed("备份目录名称已存在")
            }
            try fm.moveItem(at: working, to: published)
            return published
        } catch {
            try? fm.removeItem(at: working)
            throw error
        }
    }

    static func verify(_ folder: URL) throws -> Int {
        try verifyFiles(in: folder.appendingPathComponent("Payload", isDirectory: true), usingManifestAt: folder)
    }

    // The same manifest verification is used for a staged restore payload
    // and for post-commit recovery checks.
    static func verifyFiles(in payload: URL, usingManifestAt folder: URL) throws -> Int {
        let trustedFolder = try validatedBackupFolder(folder)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: Data(contentsOf: trustedFolder.appendingPathComponent("manifest.json")))
        guard manifest.formatVersion == 1 || manifest.formatVersion == 2 else {
            throw BackupError.verificationFailed("不支持的备份清单版本")
        }
        if manifest.formatVersion == 2 {
            guard let expected = manifest.directories,
                  Set(expected).count == expected.count,
                  expected == (try directoryPaths(in: payload)) else {
                throw BackupError.verificationFailed("备份目录结构不匹配")
            }
        }
        let current = try digests(in: payload)
        guard current.count == manifest.files.count else {
            throw BackupError.verificationFailed("数量不一致")
        }
        let paths = manifest.files.map(\.relativePath)
        guard Set(paths).count == paths.count else {
            throw BackupError.verificationFailed("备份清单存在重复路径")
        }
        let known = Dictionary(uniqueKeysWithValues: manifest.files.map { ($0.relativePath, $0) })
        for entry in current {
            guard let expected = known[entry.relativePath], expected.byteCount == entry.byteCount, expected.sha256 == entry.sha256 else {
                throw BackupError.verificationFailed(entry.relativePath)
            }
        }
        return current.count
    }

    /// V2 records all relative directory paths, including empty folders.
    /// File checksums alone cannot tell that an empty directory disappeared.
    private static func directoryPaths(in root: URL) throws -> [String] {
        let fm = FileManager.default
        let flags = try root.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        guard flags.isDirectory == true, flags.isSymbolicLink != true else {
            throw BackupError.verificationFailed("备份目录缺失或包含符号链接")
        }
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
        ]) else { throw BackupError.verificationFailed("无法检查备份目录") }
        let prefix = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        var directories: [String] = []
        while let item = enumerator.nextObject() as? URL {
            let values = try item.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
            ])
            guard values.isSymbolicLink != true else {
                throw BackupError.symbolicLinkNotAllowed
            }
            if values.isDirectory == true {
                let parts = item.resolvingSymlinksInPath().standardizedFileURL.pathComponents
                guard parts.count > prefix.count, parts.starts(with: prefix) else {
                    throw BackupError.verificationFailed("目录超出备份范围")
                }
                directories.append(parts.dropFirst(prefix.count).joined(separator: "/"))
            } else if values.isRegularFile != true {
                throw BackupError.verificationFailed("备份包含不支持的特殊文件")
            }
        }
        return directories.sorted()
    }

    private static func rejectSymlinks(in root: URL) throws {
        let fm = FileManager.default
        let rootFlags = try root.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        guard rootFlags.isDirectory == true,
              rootFlags.isSymbolicLink != true else {
            throw BackupError.symbolicLinkNotAllowed
        }
        guard let enumerator = fm.enumerator(
            at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]
        ) else {
            throw BackupError.verificationFailed("无法遍历备份数据源")
        }
        while let item = enumerator.nextObject() as? URL {
            if (try item.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
                throw BackupError.symbolicLinkNotAllowed
            }
        }
    }

    private static func digests(in root: URL) throws -> [FileDigest] {
        let fm = FileManager.default
        let rootFlags = try root.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey
        ])
        guard rootFlags.isDirectory == true,
              rootFlags.isSymbolicLink != true else {
            throw BackupError.verificationFailed("备份 Payload 缺失或为符号链接")
        }
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [
            .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
        ]) else { throw BackupError.verificationFailed("无法枚举备份内容") }
        var result: [FileDigest] = []
        while let file = enumerator.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey
            ])
            guard values.isSymbolicLink != true else { throw BackupError.symbolicLinkNotAllowed }
            if values.isDirectory == true { continue }
            guard values.isRegularFile == true else {
                throw BackupError.verificationFailed("备份包含不支持的特殊文件")
            }
            // A path can be presented as /var/... or /private/var/... on
            // macOS. Never compute relative paths by trimming a string length;
            // canonicalize both URLs and compare full path components instead.
            let rootParts = root.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            let fileParts = file.resolvingSymlinksInPath().standardizedFileURL.pathComponents
            guard fileParts.count > rootParts.count,
                  fileParts.starts(with: rootParts) else {
                throw BackupError.verificationFailed("文件路径超出备份目录：" + file.lastPathComponent)
            }
            let relative = fileParts.dropFirst(rootParts.count).joined(separator: "/")
            result.append(FileDigest(relativePath: relative, byteCount: Int64(values.fileSize ?? 0), sha256: try sha256(file)))
        }
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    private static func sha256(_ url: URL) throws -> String {
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        var digest = SHA256()
        while let data = try reader.read(upToCount: 1024 * 1024), !data.isEmpty {
            digest.update(data: data)
        }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
