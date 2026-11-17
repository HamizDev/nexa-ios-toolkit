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

    static func listBackups() throws -> [BackupRecord] {
        let fm = FileManager.default
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        return try fm.contentsOfDirectory(at: backupFolder, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .map { BackupRecord(folder: $0) }
    }

    static func createBackup() throws -> URL {
        let fm = FileManager.default
        let source = AppPaths.importFolder
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        let imports = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        guard !imports.isEmpty else { throw BackupError.emptySource }
        try rejectSymlinks(in: source)
        try fm.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        let folder = backupFolder.appendingPathComponent(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-") + "_" + String(UUID().uuidString.prefix(6)), isDirectory: true)
        let payload = folder.appendingPathComponent("Payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        do {
            for item in imports {
                try fm.copyItem(at: item, to: payload.appendingPathComponent(item.lastPathComponent))
            }
            let manifest = BackupManifest(createdAt: Date(), files: try digests(in: payload), formatVersion: 1)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(manifest).write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
            return folder
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
    }

    static func verify(_ folder: URL) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(BackupManifest.self, from: Data(contentsOf: folder.appendingPathComponent("manifest.json")))
        let payload = folder.appendingPathComponent("Payload", isDirectory: true)
        let current = try digests(in: payload)
        guard current.count == manifest.files.count else {
            throw BackupError.verificationFailed("数量不一致")
        }
        let known = Dictionary(uniqueKeysWithValues: manifest.files.map { ($0.relativePath, $0) })
        for entry in current {
            guard let expected = known[entry.relativePath], expected.byteCount == entry.byteCount, expected.sha256 == entry.sha256 else {
                throw BackupError.verificationFailed(entry.relativePath)
            }
        }
        return current.count
    }

    private static func rejectSymlinks(in root: URL) throws {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])
        while let item = enumerator?.nextObject() as? URL {
            if (try item.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
                throw BackupError.symbolicLinkNotAllowed
            }
        }
    }

    private static func digests(in root: URL) throws -> [FileDigest] {
        let fm = FileManager.default
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        var result: [FileDigest] = []
        while let file = enumerator?.nextObject() as? URL {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true else { throw BackupError.symbolicLinkNotAllowed }
            guard values.isRegularFile == true else { continue }
            let prefix = root.path + "/"
            let relative = String(file.path.dropFirst(prefix.count))
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
