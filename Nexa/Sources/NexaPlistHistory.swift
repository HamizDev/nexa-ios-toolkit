import Foundation
import CryptoKit

/// Versioned, integrity-checked undo history for plist files imported into Nexa.
/// Never opens a device MobileGestalt cache or any other app's private container.
enum NexaPlistHistory {
    enum Failure: LocalizedError {
        case outOfScope, symbolLink, invalidFile, tooLarge, missingVersion, damagedVersion
        var errorDescription: String? {
            switch self {
            case .outOfScope: return "Only imported Nexa plist copies can be restored."
            case .symbolLink: return "Symbolic links are not supported."
            case .invalidFile: return "The selected file is not a regular plist file."
            case .tooLarge: return "A plist version exceeds the 16 MB safety limit."
            case .missingVersion: return "The selected previous version was not found."
            case .damagedVersion: return "This previous version failed SHA-256 verification."
            }
        }
    }

    struct Record: Codable, Identifiable {
        let id: UUID
        let savedAt: Date
        let filename: String
        let byteCount: Int
        let sha256: String
        let sourceDigest: String
    }

    private static let maxBytes = 16 * 1024 * 1024
    private static let lock = NSRecursiveLock()

    private static var vault: URL {
        #if NEXA_LOCAL_TEST
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Nexa/PlistVersions", isDirectory: true)
        }
        #endif
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa/PlistVersions", isDirectory: true)
    }

    private static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validate(_ input: URL) throws -> URL {
        let original = input.standardizedFileURL
        let root = AppPaths.importFolder.standardizedFileURL
        let resolved = original.resolvingSymlinksInPath().standardizedFileURL
        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard !input.pathComponents.contains(".."),
              resolved.pathComponents.starts(with: canonicalRoot.pathComponents),
              resolved.pathComponents.count > canonicalRoot.pathComponents.count,
              resolved.pathExtension.lowercased() == "plist" else {
            throw Failure.outOfScope
        }
        var next = original
        while next.pathComponents.count >= root.pathComponents.count {
            if (try? next.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw Failure.symbolLink
            }
            if next.pathComponents.count == root.pathComponents.count { break }
            next.deleteLastPathComponent()
        }
        let flags = try resolved.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard flags.isRegularFile == true, flags.isSymbolicLink != true else {
            throw Failure.invalidFile
        }
        guard (flags.fileSize ?? 0) <= maxBytes else { throw Failure.tooLarge }
        return resolved
    }

    private static func sourceKey(_ file: URL) -> String {
        hex(Data(file.path.utf8))
    }

    private static func directory(_ file: URL) -> URL {
        vault.appendingPathComponent(sourceKey(file), isDirectory: true)
    }

    private static func recordURL(_ record: Record, for file: URL) -> URL {
        directory(file).appendingPathComponent(record.id.uuidString + ".json")
    }

    static func snapshotURL(_ record: Record, for source: URL) throws -> URL {
        let file = try validate(source)
        let stored = directory(file).appendingPathComponent(record.id.uuidString + ".plist")
        guard FileManager.default.fileExists(atPath: stored.path) else { throw Failure.missingVersion }
        return stored
    }

    @discardableResult
    static func backup(file: URL, originalData: Data? = nil) throws -> Record {
        lock.lock()
        defer { lock.unlock() }
        let target = try validate(file)
        let raw = try originalData ?? Data(contentsOf: target)
        guard raw.count <= maxBytes else { throw Failure.tooLarge }
        // Only store files which are valid property lists. A history snapshot is
        // intended to be safe to restore, not an arbitrary binary archive.
        _ = try PropertyListSerialization.propertyList(from: raw, options: [], format: nil)
        let record = Record(id: UUID(), savedAt: Date(),
                            filename: target.lastPathComponent, byteCount: raw.count,
                            sha256: hex(raw), sourceDigest: sourceKey(target))
        let folder = directory(target)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stored = folder.appendingPathComponent(record.id.uuidString + ".plist")
        do {
            try raw.write(to: stored, options: .atomic)
            try JSONEncoder().encode(record).write(to: recordURL(record, for: target), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: stored)
            throw error
        }
        return record
    }

    static func versions(for source: URL) throws -> [Record] {
        lock.lock()
        defer { lock.unlock() }
        let file = try validate(source)
        let folder = directory(file)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey]
        ).compactMap { url in
            guard url.pathExtension == "json",
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let raw = try? Data(contentsOf: url),
                  let record = try? JSONDecoder().decode(Record.self, from: raw),
                  record.id == id, record.sourceDigest == sourceKey(file),
                  record.filename == file.lastPathComponent,
                  FileManager.default.fileExists(atPath:
                    folder.appendingPathComponent(id.uuidString + ".plist").path) else {
                return nil
            }
            return record
        }.sorted { $0.savedAt > $1.savedAt }
    }

    /// Saves the currently edited copy before restoring an older version, so
    /// the user can undo the restore. Never overwrites the historical snapshot.
    @discardableResult
    static func restore(_ selected: Record, to source: URL) throws -> Record {
        lock.lock()
        defer { lock.unlock() }
        let target = try validate(source)
        guard let saved = try versions(for: target).first(where: { $0.id == selected.id }),
              saved.sha256 == selected.sha256,
              saved.byteCount == selected.byteCount else {
            throw Failure.missingVersion
        }
        let path = try snapshotURL(saved, for: target)
        let data = try Data(contentsOf: path)
        guard data.count == saved.byteCount, hex(data) == saved.sha256 else {
            throw Failure.damagedVersion
        }
        _ = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        let current = try Data(contentsOf: target)
        let previous = try backup(file: target, originalData: current)
        try data.write(to: target, options: .atomic)
        return previous
    }
}
