import Foundation
import CryptoKit

/// WCMigrate-style local staging for user-imported directory trees.
/// The original source is NEVER removed. No other app containers are accessed.
/// This supplements the pinned upstream progress and identity components.
enum NexaImportMigration {
    enum Failure: LocalizedError {
        case invalidFolder, nestedTarget, symbolLink, unsupportedEntry
        case conflict, changed, manifestMismatch, tooManyEntries, incomplete
        var errorDescription: String? {
            switch self {
            case .invalidFolder: return "Select two separate directories inside Nexa Imports."
            case .nestedTarget: return "The destination cannot be inside the source."
            case .symbolLink: return "Symbolic links cannot be migrated."
            case .unsupportedEntry: return "Unsupported special file found."
            case .conflict: return "The destination already exists. No files were overwritten."
            case .changed: return "The source changed during staging; no destination files were modified."
            case .manifestMismatch: return "SHA-256 manifest verification failed."
            case .tooManyEntries: return "Too many entries for one migration (limit 100,000)."
            case .incomplete: return "An interrupted migration needs manual review."
            }
        }
    }

    struct Digest: Codable, Equatable {
        var path: String
        var bytes: Int64
        var sha256: String
    }

    struct Plan {
        let source: URL
        let destination: URL
        let files: [Digest]
        let totalBytes: Int64
    }

    struct Receipt: Identifiable, Codable {
        enum State: String, Codable { case staging, complete, failed }
        let id: UUID
        let created: Date
        let source: String
        let destination: String
        let finalFolderName: String
        let files: [Digest]
        var state: State
        var idString: String { id.uuidString }
        var fileCount: Int { files.count }
        var totalBytes: Int64 { files.reduce(0) { $0 + $1.bytes } }
    }

    private static let lock = NSRecursiveLock()
    private static let manager = FileManager.default
    private static let fileLimit = 100_000

    private static var stagingRoot: URL {
        AppPaths.documents.appendingPathComponent("ImportMigrationStaging", isDirectory: true)
    }

    private static var receiptRoot: URL {
        #if NEXA_LOCAL_TEST
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Nexa/ImportMigrations", isDirectory: true)
        }
        #endif
        return manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa/ImportMigrations", isDirectory: true)
    }

    private static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    // Canonical containment is necessary but not sufficient: reject each
    // existing lexical ancestor's symlink before following its contents.
    private static func folder(_ url: URL, canBeRoot: Bool) throws -> URL {
        let root = AppPaths.importFolder.standardizedFileURL
        let input = url.standardizedFileURL
        let resolvedRoot = canonical(root)
        let resolved = canonical(input)
        let rootParts = resolvedRoot.pathComponents
        guard resolved.pathComponents.starts(with: rootParts),
              resolved.pathComponents.count >= rootParts.count + (canBeRoot ? 0 : 1),
              input.pathComponents.count >= root.pathComponents.count,
              input.pathComponents.starts(with: root.pathComponents) ||
                resolved.pathComponents.starts(with: rootParts) else {
            throw Failure.invalidFolder
        }
        var cursor = input
        while cursor.pathComponents.count >= root.pathComponents.count {
            if (try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw Failure.symbolLink
            }
            if cursor.pathComponents.count == root.pathComponents.count { break }
            cursor.deleteLastPathComponent()
        }
        let values = try resolved.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw Failure.invalidFolder
        }
        return resolved
    }

    private static func hashFile(_ url: URL) throws -> String {
        let stream = InputStream(url: url)
        guard let stream else { throw Failure.unsupportedEntry }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        var buf = [UInt8](repeating: 0, count: 128 * 1024)
        while stream.hasBytesAvailable {
            let n = stream.read(&buf, maxLength: buf.count)
            if n < 0 { throw stream.streamError ?? Failure.unsupportedEntry }
            if n == 0 { break }
            hasher.update(data: Data(buf[0..<n]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func inventory(_ folder: URL) throws -> [Digest] {
        let base = canonical(folder)
        let baseParts = base.pathComponents
        guard let walker = manager.enumerator(
            at: base,
            includingPropertiesForKeys: [
                .isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey
            ],
            options: []
        ) else { throw Failure.invalidFolder }
        var files: [Digest] = []
        var count = 0
        while let item = walker.nextObject() as? URL {
            count += 1
            if count > fileLimit { throw Failure.tooManyEntries }
            let flags = try item.resourceValues(forKeys: [
                .isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey
            ])
            if flags.isSymbolicLink == true { throw Failure.symbolLink }
            if flags.isDirectory == true { continue }
            guard flags.isRegularFile == true else { throw Failure.unsupportedEntry }
            let canonicalPath = canonical(item)
            guard canonicalPath.pathComponents.starts(with: baseParts),
                  canonicalPath.pathComponents.count > baseParts.count else {
                throw Failure.invalidFolder
            }
            let relative = canonicalPath.pathComponents.dropFirst(baseParts.count).joined(separator: "/")
            files.append(Digest(path: relative,
                                bytes: Int64(flags.fileSize ?? 0),
                                sha256: try hashFile(item)))
        }
        return files.sorted { $0.path < $1.path }
    }

    static func availableFolders(limit: Int = 200) throws -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        let root = try folder(AppPaths.importFolder, canBeRoot: true)
        var pending = [root]
        var found: [URL] = []
        while !pending.isEmpty && found.count < min(max(limit, 1), 500) {
            let next = pending.removeFirst()
            found.append(next)
            for child in try NexaLocalFiles.list(in: next) {
                if (try child.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true {
                    pending.append(child)
                }
            }
        }
        return found
    }

    static func preview(source: URL, destination: URL) throws -> Plan {
        lock.lock()
        defer { lock.unlock() }
        let from = try folder(source, canBeRoot: false)
        let into = try folder(destination, canBeRoot: true)
        guard from != into, !into.pathComponents.starts(with: from.pathComponents) else {
            throw Failure.nestedTarget
        }
        let files = try inventory(from)
        return Plan(source: from, destination: into, files: files,
                    totalBytes: files.reduce(0) { $0 + $1.bytes })
    }

    private static func receiptURL(_ id: UUID) -> URL {
        receiptRoot.appendingPathComponent(id.uuidString + ".json")
    }

    private static func save(_ item: Receipt) throws {
        try manager.createDirectory(at: receiptRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(item).write(to: receiptURL(item.id), options: .atomic)
    }

    static func receipts() throws -> [Receipt] {
        lock.lock()
        defer { lock.unlock() }
        try manager.createDirectory(at: receiptRoot, withIntermediateDirectories: true)
        let paths = try manager.contentsOfDirectory(
            at: receiptRoot, includingPropertiesForKeys: [.isRegularFileKey]
        )
        return paths.compactMap { path in
            guard path.pathExtension == "json",
                  UUID(uuidString: path.deletingPathExtension().lastPathComponent) != nil,
                  let raw = try? Data(contentsOf: path),
                  let record = try? JSONDecoder().decode(Receipt.self, from: raw),
                  path.lastPathComponent == record.id.uuidString + ".json" else { return nil }
            return record
        }.sorted { $0.created > $1.created }
    }

    /// Crash recovery is deliberately conservative. A verified destination can
    /// finish an interrupted commit; a stale/staging-only record is marked
    /// failed and source remains untouched. No automatic conflicting overwrite.
    static func recoverIfNeeded() throws {
        lock.lock()
        defer { lock.unlock() }
        for var record in try receipts() where record.state == .staging {
            let destination = try folder(
                AppPaths.importFolder.appendingPathComponent(record.destination),
                canBeRoot: true
            )
            let output = destination.appendingPathComponent(record.finalFolderName)
            if manager.fileExists(atPath: output.path),
               (try? inventory(output)) == record.files {
                record.state = .complete
            } else {
                record.state = .failed
            }
            try save(record)
        }
    }

    static func execute(_ proposal: Plan) throws -> Receipt {
        lock.lock()
        defer { lock.unlock() }
        let current = try preview(source: proposal.source, destination: proposal.destination)
        guard current.files == proposal.files else { throw Failure.changed }
        let id = UUID()
        let name = "NexaMigration-" + id.uuidString.prefix(8)
        let root = try folder(proposal.destination, canBeRoot: true)
        let target = root.appendingPathComponent(name, isDirectory: true)
        guard !manager.fileExists(atPath: target.path) else { throw Failure.conflict }

        let parts = canonical(AppPaths.importFolder).pathComponents
        let targetRelative = root.pathComponents.dropFirst(parts.count).joined(separator: "/")
        let sourceRelative = current.source.pathComponents.dropFirst(parts.count).joined(separator: "/")
        var receipt = Receipt(
            id: id, created: Date(), source: sourceRelative,
            destination: targetRelative, finalFolderName: name,
            files: current.files, state: .staging
        )
        let tempRoot = stagingRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        let temp = tempRoot.appendingPathComponent("Payload", isDirectory: true)
        try manager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        do {
            try manager.copyItem(at: current.source, to: temp)
            guard try inventory(temp) == current.files else { throw Failure.changed }
            // Check the original again before committing. No source deletion.
            guard try inventory(current.source) == current.files else { throw Failure.changed }
            try save(receipt)
            guard !manager.fileExists(atPath: target.path) else { throw Failure.conflict }
            try manager.moveItem(at: temp, to: target)
            guard try inventory(target) == current.files else { throw Failure.manifestMismatch }
            receipt.state = .complete
            try save(receipt)
            try? manager.removeItem(at: tempRoot)
            return receipt
        } catch {
            if !manager.fileExists(atPath: target.path) {
                try? manager.removeItem(at: tempRoot)
            }
            // If the journal exists, recovery can identify completed results.
            if manager.fileExists(atPath: receiptURL(id).path) {
                try? recoverIfNeeded()
            }
            throw error
        }
    }
}
