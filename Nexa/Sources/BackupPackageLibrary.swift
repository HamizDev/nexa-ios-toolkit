import Foundation

struct FileDigest: Codable, Equatable {
    let relativePath: String
    let byteCount: Int64
    let sha256: String
}

struct BackupManifest: Codable {
    let createdAt: Date
    let files: [FileDigest]
    let formatVersion: Int
    let directories: [String]?
}

struct BackupRecord: Identifiable {
    let folder: URL
    let manifest: BackupManifest?
    let logicalBytes: Int64?
    var id: String { folder.path }
    var name: String { folder.lastPathComponent }
}

// Foundation-only package management. SHA-256 verification is supplied by BackupManager.
enum BackupPackageLibrary {
    enum Failure: LocalizedError {
        case invalidPackage, outsideLibrary, unsupportedVersion(Int), sizeOverflow
        var errorDescription: String? { message(in: "en") }
        func message(in language: String) -> String {
            let en = language == "en"
            switch self {
            case .invalidPackage: return en ? "Invalid backup folder or manifest." : "备份目录或清单无效。"
            case .outsideLibrary: return en ? "Backup is outside the local backup library." : "备份不在本地备份库内。"
            case .unsupportedVersion(let version): return en ? "Unsupported backup format: \(version)" : "不支持的备份格式：\(version)"
            case .sizeOverflow: return en ? "Backup size cannot be represented." : "无法统计备份大小。"
            }
        }
    }

    static let manifestLimit = 32 * 1024 * 1024
    private static let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]

    static func requireDirectory(_ url: URL) throws {
        guard url.isFileURL else { throw Failure.invalidPackage }
        let flags = try URL(fileURLWithPath: url.path).resourceValues(forKeys: keys)
        guard flags.isDirectory == true, flags.isSymbolicLink != true else { throw Failure.invalidPackage }
    }

    static func checkedFolder(_ folder: URL, root: URL) throws -> URL {
        let target = folder.standardizedFileURL
        guard folder.isFileURL, root.isFileURL,
              target.deletingLastPathComponent().path == root.standardizedFileURL.path,
              !target.lastPathComponent.hasPrefix(".") else { throw Failure.outsideLibrary }
        try requireDirectory(root)
        try requireDirectory(target)
        return target
    }

    static func manifest(in folder: URL) throws -> BackupManifest {
        try requireDirectory(folder)
        let fm = FileManager.default
        let names = try fm.contentsOfDirectory(atPath: folder.path)
        guard Set(names) == Set(["manifest.json", "Payload"]) else { throw Failure.invalidPackage }
        try requireDirectory(folder.appendingPathComponent("Payload", isDirectory: true))
        let url = folder.appendingPathComponent("manifest.json")
        let flags = try URL(fileURLWithPath: url.path).resourceValues(forKeys: keys)
        guard flags.isRegularFile == true, flags.isSymbolicLink != true,
              let size = flags.fileSize, size >= 0, size <= manifestLimit else { throw Failure.invalidPackage }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= manifestLimit {
            guard let chunk = try handle.read(upToCount: min(64 * 1024, manifestLimit + 1 - data.count)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count <= manifestLimit else { throw Failure.invalidPackage }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(BackupManifest.self, from: data)
        guard result.formatVersion == 1 || result.formatVersion == 2 else { throw Failure.unsupportedVersion(result.formatVersion) }
        guard Set(result.files.map(\.relativePath)).count == result.files.count,
              result.files.allSatisfy({ $0.byteCount >= 0 }) else { throw Failure.invalidPackage }
        if result.formatVersion == 2 {
            guard let dirs = result.directories, Set(dirs).count == dirs.count else { throw Failure.invalidPackage }
        }
        return result
    }

    // Sum logical file lengths, not allocated blocks; reject links and special files.
    static func logicalBytes(in folder: URL) throws -> Int64 {
        try requireDirectory(folder)
        var stack = [folder]
        var bytes: Int64 = 0
        let fm = FileManager.default
        while let item = stack.popLast() {
            let flags = try URL(fileURLWithPath: item.path).resourceValues(forKeys: keys)
            guard flags.isSymbolicLink != true else { throw Failure.invalidPackage }
            if flags.isDirectory == true {
                stack.append(contentsOf: try fm.contentsOfDirectory(at: item, includingPropertiesForKeys: Array(keys)))
            } else {
                guard flags.isRegularFile == true, let size = flags.fileSize, size >= 0 else { throw Failure.invalidPackage }
                let (sum, overflow) = bytes.addingReportingOverflow(Int64(size))
                guard !overflow else { throw Failure.sizeOverflow }
                bytes = sum
            }
        }
        return bytes
    }

    static func list(root: URL) throws -> [BackupRecord] {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try requireDirectory(root)
        let folders = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return folders.compactMap { folder in
            guard let checked = try? checkedFolder(folder, root: root) else { return nil }
            let bytes = try? logicalBytes(in: checked)
            let metadata = bytes == nil ? nil : try? manifest(in: checked)
            return BackupRecord(folder: checked, manifest: metadata, logicalBytes: bytes)
        }.sorted {
            let left = $0.manifest?.createdAt ?? .distantPast
            let right = $1.manifest?.createdAt ?? .distantPast
            return left == right ? $0.name > $1.name : left > right
        }
    }

    static func knownLogicalBytes(_ records: [BackupRecord]) -> Int64? {
        var total: Int64 = 0
        for record in records {
            guard let bytes = record.logicalBytes else { continue }
            let (sum, overflow) = total.addingReportingOverflow(bytes)
            guard !overflow else { return nil }
            total = sum
        }
        return total
    }

    // Keep staging outside the visible library entries. The verifier must validate every payload hash.
    static func importFolder(_ source: URL, root: URL, verify: (URL, URL) throws -> Void) throws -> URL {
        let fm = FileManager.default
        _ = try manifest(in: source)
        _ = try logicalBytes(in: source)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try requireDirectory(root)
        let token = UUID().uuidString
        let staging = root.appendingPathComponent(".pending-import-" + token, isDirectory: true)
        let candidate = staging.appendingPathComponent("Package", isDirectory: true)
        let destination = root.appendingPathComponent("Imported-" + token, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: candidate)
        _ = try manifest(in: candidate)
        _ = try logicalBytes(in: candidate)
        try verify(candidate, staging)
        try fm.moveItem(at: candidate, to: destination)
        return destination
    }

    // A damaged package may still be removed, but never the root or an external path.
    static func remove(_ folder: URL, root: URL) throws {
        let checked = try checkedFolder(folder, root: root)
        try FileManager.default.removeItem(at: checked)
    }
}
