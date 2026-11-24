import Foundation

// Portable backup orchestration. Production supplies WQFiles' ZIP codec and
// BackupManager's SHA-256 verifier; no platform-specific archive code here.
enum BackupZipTransport {
    struct Limits {
        let expandedBytes: Int64
        let archiveBytes: Int64
        let entries: Int
        static let standard = Limits(expandedBytes: 2 * 1024 * 1024 * 1024,
                                     archiveBytes: 2304 * 1024 * 1024, entries: 65_535)
    }

    enum Failure: LocalizedError {
        case invalidPackage, outsideLibrary, limitExceeded, incompleteRoundTrip, skippedEntries
        var errorDescription: String? { message(in: "en") }
        func message(in language: String) -> String {
            let en = language == "en"
            switch self {
            case .invalidPackage: return en ? "Invalid backup ZIP or folder." : "备份 ZIP 或目录无效。"
            case .outsideLibrary: return en ? "Backup is outside the local library." : "备份不在本地备份库内。"
            case .limitExceeded: return en ? "Portable backup exceeds the ZIP size or entry limit." : "便携备份超过 ZIP 大小或条目数量限制。"
            case .incompleteRoundTrip: return en ? "The ZIP round trip did not preserve the backup." : "ZIP 往返校验未完整保留备份。"
            case .skippedEntries: return en ? "Some archive entries were skipped. Backup ZIP rejected." : "压缩包有条目被跳过，已拒绝该备份 ZIP。"
            }
        }
    }

    typealias Verify = (URL, URL) throws -> Void
    typealias Write = ([URL], URL) throws -> Void
    typealias Extract = (URL, URL, UInt64) throws -> Void

    private struct Tree: Equatable {
        // Directory marker -1; other values are logical file lengths.
        let entries: [String: Int64]
        let bytes: Int64
    }

    private static let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]

    static func export(_ folder: URL, backupRoot: URL, archiveRoot: URL,
                       limits: Limits = .standard, verify: Verify, write: Write, extract: Extract) throws -> URL {
        let fm = FileManager.default
        let source = folder.standardizedFileURL
        guard folder.isFileURL, backupRoot.isFileURL,
              source.deletingLastPathComponent().path == backupRoot.standardizedFileURL.path,
              !source.lastPathComponent.hasPrefix(".") else { throw Failure.outsideLibrary }
        try requireDirectory(backupRoot)
        try verify(source, backupRoot)
        let original = try tree(source, limits: limits)
        let manifest = try manifestBytes(source, inventory: original)
        try fm.createDirectory(at: archiveRoot, withIntermediateDirectories: true)
        try requireDirectory(archiveRoot)
        let token = UUID().uuidString
        let work = archiveRoot.appendingPathComponent(".pending-backup-" + token, isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: work) }
        let stagedZip = work.appendingPathComponent("Backup.zip")
        let roundTrip = work.appendingPathComponent("Package", isDirectory: true)
        try write([source.appendingPathComponent("manifest.json"), source.appendingPathComponent("Payload", isDirectory: true)], stagedZip)
        try requireZip(stagedZip, limits: limits)
        try fm.createDirectory(at: roundTrip, withIntermediateDirectories: false)
        try extract(stagedZip, roundTrip, UInt64(limits.expandedBytes))
        let restored = try tree(roundTrip, limits: limits)
        guard restored == original, try manifestBytes(roundTrip, inventory: restored) == manifest else {
            throw Failure.incompleteRoundTrip
        }
        try verify(roundTrip, work)
        let output = archiveRoot.appendingPathComponent("Nexa-Backup-" + token + ".zip")
        try fm.moveItem(at: stagedZip, to: output)
        return output
    }

    static func importZIP(_ archive: URL, backupRoot: URL, limits: Limits = .standard,
                          verify: Verify, extract: Extract) throws -> URL {
        let fm = FileManager.default
        try requireZip(archive, limits: limits)
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        try requireDirectory(backupRoot)
        let token = UUID().uuidString
        let work = backupRoot.appendingPathComponent(".pending-zip-" + token, isDirectory: true)
        try fm.createDirectory(at: work, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: work) }
        let candidate = work.appendingPathComponent("Package", isDirectory: true)
        try fm.createDirectory(at: candidate, withIntermediateDirectories: false)
        try extract(archive, candidate, UInt64(limits.expandedBytes))
        let inventory = try tree(candidate, limits: limits)
        _ = try manifestBytes(candidate, inventory: inventory)
        try verify(candidate, work)
        let destination = backupRoot.appendingPathComponent("Imported-ZIP-" + token, isDirectory: true)
        try fm.moveItem(at: candidate, to: destination)
        return destination
    }

    private static func requireDirectory(_ url: URL) throws {
        guard url.isFileURL else { throw Failure.invalidPackage }
        let flags = try URL(fileURLWithPath: url.path).resourceValues(forKeys: keys)
        guard flags.isDirectory == true, flags.isSymbolicLink != true else { throw Failure.invalidPackage }
    }

    private static func requireZip(_ url: URL, limits: Limits) throws {
        guard url.isFileURL, url.pathExtension.lowercased() == "zip",
              limits.expandedBytes >= 0, limits.archiveBytes >= 0, limits.entries > 0 else { throw Failure.invalidPackage }
        let flags = try URL(fileURLWithPath: url.path).resourceValues(forKeys: keys)
        guard flags.isRegularFile == true, flags.isSymbolicLink != true,
              let size = flags.fileSize, size > 0 else { throw Failure.invalidPackage }
        guard Int64(size) <= limits.archiveBytes else { throw Failure.limitExceeded }
    }

    private static func tree(_ root: URL, limits: Limits) throws -> Tree {
        try requireDirectory(root)
        let fm = FileManager.default
        var stack: [(URL, String)] = [(root, "")]
        var entries: [String: Int64] = [:]
        var bytes: Int64 = 0
        while let (directory, parent) = stack.popLast() {
            for child in try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) {
                let name = child.lastPathComponent
                let relative = parent.isEmpty ? name : parent + "/" + name
                let flags = try URL(fileURLWithPath: child.path).resourceValues(forKeys: keys)
                guard flags.isSymbolicLink != true else { throw Failure.invalidPackage }
                guard entries.count < limits.entries else { throw Failure.limitExceeded }
                if flags.isDirectory == true {
                    entries[relative] = -1
                    stack.append((child, relative))
                } else {
                    guard flags.isRegularFile == true, let length = flags.fileSize, length >= 0 else { throw Failure.invalidPackage }
                    let (sum, overflow) = bytes.addingReportingOverflow(Int64(length))
                    guard !overflow, sum <= limits.expandedBytes else { throw Failure.limitExceeded }
                    bytes = sum
                    entries[relative] = Int64(length)
                }
            }
        }
        return Tree(entries: entries, bytes: bytes)
    }

    private static func manifestBytes(_ root: URL, inventory: Tree) throws -> Data {
        guard let size = inventory.entries["manifest.json"], size >= 0, size <= 32 * 1024 * 1024,
              inventory.entries["Payload"] == -1,
              inventory.entries.keys.allSatisfy({ $0 == "manifest.json" || $0 == "Payload" || $0.hasPrefix("Payload/") }) else {
            throw Failure.invalidPackage
        }
        // The verifier also bounds and parses the manifest; this compares the exact bytes.
        let handle = try FileHandle(forReadingFrom: root.appendingPathComponent("manifest.json"))
        defer { try? handle.close() }
        var data = Data()
        while data.count <= Int(size) {
            guard let chunk = try handle.read(upToCount: min(64 * 1024, Int(size) + 1 - data.count)), !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard data.count == Int(size) else { throw Failure.invalidPackage }
        return data
    }
}
