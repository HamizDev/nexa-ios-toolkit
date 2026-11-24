import Foundation
import CryptoKit

/// Nexa-only file-level Merge/Replace for *imported snapshots*.
/// Does NOT mutate either original directory, and is not WCMigrate's original
/// DirectMigrationService or live WeChat transfer engine.
enum NexaImportCombine {
    enum Mode: String, CaseIterable, Identifiable, Codable {
        case merge, replace
        var id: String { rawValue }
    }

    enum Failure: LocalizedError {
        case invalidSelection, conflictingTypes, invalidManifest
        case changedInput, invalidSourceFile, collision, corruptResult
        var errorDescription: String? {
            switch self {
            case .invalidSelection:
                return "Choose two different imported folders that are not nested."
            case .conflictingTypes:
                return "A file conflicts with a directory in the combined result."
            case .invalidManifest:
                return "An unsafe relative filename or digest was rejected."
            case .changedInput:
                return "The input folders changed after preview; no originals were modified."
            case .invalidSourceFile:
                return "A source file is missing, a symbolic link or not a regular file."
            case .collision:
                return "The result folder already exists; nothing was overwritten."
            case .corruptResult:
                return "The result did not match the expected SHA-256 inventory."
            }
        }
    }

    typealias Digest = NexaImportMigration.Digest

    struct Plan {
        let source: URL
        let target: URL
        let mode: Mode
        let sourceFiles: [Digest]
        let targetFiles: [Digest]
        let expectedFiles: [Digest]
        let overlaps: Int
        let retainedTargetFiles: Int
        var resultBytes: Int64 { expectedFiles.reduce(0) { $0 + $1.bytes } }
    }

    struct Receipt: Codable, Identifiable {
        enum State: String, Codable { case pending, complete, failed }
        let id: UUID
        let createdAt: Date
        let mode: Mode
        let sourceRelative: String
        let targetRelative: String
        let resultName: String
        let files: [Digest]
        var state: State
        var fileCount: Int { files.count }
    }

    private static let lock = NSRecursiveLock()
    private static let fm = FileManager.default

    private static var stageRoot: URL {
        AppPaths.documents.appendingPathComponent("ImportCombineStaging", isDirectory: true)
    }

    private static var receiptsRoot: URL {
        #if NEXA_LOCAL_TEST
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Nexa/ImportCombinations", isDirectory: true)
        }
        #endif
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa/ImportCombinations", isDirectory: true)
    }

    private static func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    private static func relativeParts(_ path: String) throws -> [String] {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !path.isEmpty, !path.hasPrefix("/"), parts.allSatisfy({
            !$0.isEmpty && $0 != "." && $0 != ".." &&
            !$0.contains("\\") && !$0.contains("\0")
        }) else { throw Failure.invalidManifest }
        return parts
    }

    private static func append(_ parts: [String], to root: URL) -> URL {
        parts.reduce(root) { $0.appendingPathComponent($1) }
    }

    private static func valid(_ digest: Digest) -> Bool {
        guard (try? relativeParts(digest.path)) != nil,
              digest.bytes >= 0, digest.sha256.utf8.count == 64 else { return false }
        return digest.sha256.utf8.allSatisfy {
            ($0 >= 48 && $0 <= 57) || ($0 >= 97 && $0 <= 102)
        }
    }

    private static func validateManifest(_ files: [Digest]) throws {
        guard files.count <= 100_000,
              files.allSatisfy(valid) else { throw Failure.invalidManifest }
        let names = Set(files.map(\.path))
        guard names.count == files.count else { throw Failure.invalidManifest }
        // A path is invalid when ANY ancestor is already a regular file.
        // Checking only adjacent sorted paths misses cases such as
        // "alpha", "alpha-bridge", "alpha/child" (ASCII '-' precedes '/').
        // Check each slash-delimited ancestor regardless of lexical order.
        for path in names {
            for slash in path.indices where path[slash] == "/" {
                if names.contains(String(path[..<slash])) {
                    throw Failure.conflictingTypes
                }
            }
        }
    }

    private static func importedInventory(_ folder: URL) throws -> [Digest] {
        try NexaImportMigration.preview(
            source: folder, destination: AppPaths.importFolder
        ).files
    }

    static func preview(source: URL, target: URL, mode: Mode) throws -> Plan {
        lock.lock()
        defer { lock.unlock() }
        // Validate the *original* URL before resolving symlinks. Resolving
        // first could hide a link pointing to another imported directory.
        let leftPlan = try NexaImportMigration.preview(
            source: source, destination: AppPaths.importFolder
        )
        let rightPlan = try NexaImportMigration.preview(
            source: target, destination: AppPaths.importFolder
        )
        let a = leftPlan.source, b = rightPlan.source
        let aa = a.pathComponents, bb = b.pathComponents
        guard a != b, !aa.starts(with: bb), !bb.starts(with: aa) else {
            throw Failure.invalidSelection
        }
        let left = leftPlan.files
        let right = rightPlan.files
        try validateManifest(left)
        try validateManifest(right)
        var selected: [String: Digest] = [:]
        if mode == .merge {
            for file in right { selected[file.path] = file }
        }
        for file in left { selected[file.path] = file }
        let expected = selected.values.sorted { $0.path < $1.path }
        try validateManifest(expected)
        let rightNames = Set(right.map(\.path))
        let matching = left.filter { rightNames.contains($0.path) }.count
        return Plan(source: a, target: b, mode: mode,
                    sourceFiles: left, targetFiles: right, expectedFiles: expected,
                    overlaps: matching,
                    retainedTargetFiles: mode == .merge ? right.count - matching : 0)
    }

    private static func receiptURL(_ id: UUID) -> URL {
        receiptsRoot.appendingPathComponent(id.uuidString + ".json")
    }

    private static func save(_ receipt: Receipt) throws {
        try fm.createDirectory(at: receiptsRoot, withIntermediateDirectories: true)
        try JSONEncoder().encode(receipt).write(to: receiptURL(receipt.id), options: .atomic)
    }

    static func receipts() throws -> [Receipt] {
        lock.lock()
        defer { lock.unlock() }
        try fm.createDirectory(at: receiptsRoot, withIntermediateDirectories: true)
        return try fm.contentsOfDirectory(
            at: receiptsRoot, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey]
        ).compactMap { url in
            guard url.pathExtension == "json",
                  (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true,
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  let data = try? Data(contentsOf: url),
                  let item = try? JSONDecoder().decode(Receipt.self, from: data),
                  item.id == id, url.lastPathComponent == item.id.uuidString + ".json" else {
                return nil
            }
            return item
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private static func verifiedOutput(_ record: Receipt) -> Bool {
        let expected = resultName(id: record.id, mode: record.mode)
        guard record.resultName == expected,
              (try? validateManifest(record.files)) != nil else { return false }
        let output = AppPaths.importFolder.appendingPathComponent(expected, isDirectory: true)
        guard let values = try? output.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        ), values.isDirectory == true, values.isSymbolicLink == false,
              let actual = try? importedInventory(output) else { return false }
        return actual == record.files
    }

    static func recoverPending() throws {
        lock.lock()
        defer { lock.unlock() }
        for var entry in try receipts() where entry.state == .pending {
            entry.state = verifiedOutput(entry) ? .complete : .failed
            try save(entry)
        }
    }

    private static func resultName(id: UUID, mode: Mode) -> String {
        "Nexa" + (mode == .merge ? "Merged-" : "Replaced-") +
            String(id.uuidString.prefix(8))
    }

    private static func readableSource(_ url: URL, root: URL) throws -> URL {
        let resolved = canonical(url)
        guard resolved.pathComponents.starts(with: canonical(root).pathComponents),
              resolved.pathComponents.count > canonical(root).pathComponents.count else {
            throw Failure.invalidSourceFile
        }
        var cursor = url.standardizedFileURL
        while cursor.pathComponents.count >= root.standardizedFileURL.pathComponents.count {
            if (try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw Failure.invalidSourceFile
            }
            if cursor.pathComponents.count == root.standardizedFileURL.pathComponents.count { break }
            cursor.deleteLastPathComponent()
        }
        let flags = try resolved.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard flags.isRegularFile == true, flags.isSymbolicLink == false else {
            throw Failure.invalidSourceFile
        }
        return resolved
    }

    private static func hexHash(_ url: URL) throws -> String {
        guard let stream = InputStream(url: url) else { throw Failure.invalidSourceFile }
        stream.open()
        defer { stream.close() }
        var hasher = SHA256()
        var bytes = [UInt8](repeating: 0, count: 128 * 1024)
        while stream.hasBytesAvailable {
            let n = stream.read(&bytes, maxLength: bytes.count)
            if n < 0 { throw stream.streamError ?? Failure.invalidSourceFile }
            if n == 0 { break }
            hasher.update(data: Data(bytes[0..<n]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Merge/Replace into a NEW directory; never edits source or target.
    static func execute(_ proposed: Plan) throws -> Receipt {
        lock.lock()
        defer { lock.unlock() }
        let checked = try preview(
            source: proposed.source, target: proposed.target, mode: proposed.mode
        )
        guard proposed.source == checked.source, proposed.target == checked.target,
              proposed.mode == checked.mode,
              proposed.sourceFiles == checked.sourceFiles,
              proposed.targetFiles == checked.targetFiles,
              proposed.expectedFiles == checked.expectedFiles else {
            throw Failure.changedInput
        }
        let id = UUID()
        let name = resultName(id: id, mode: checked.mode)
        let result = AppPaths.importFolder.appendingPathComponent(name, isDirectory: true)
        guard !fm.fileExists(atPath: result.path) else { throw Failure.collision }
        let working = stageRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        let payload = working.appendingPathComponent("Payload", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        let sourceNames = Set(checked.sourceFiles.map(\.path))
        let rootComponents = canonical(AppPaths.importFolder).pathComponents
        let originalSource = checked.source.pathComponents.dropFirst(rootComponents.count)
            .joined(separator: "/")
        let originalTarget = checked.target.pathComponents.dropFirst(rootComponents.count)
            .joined(separator: "/")
        var receipt = Receipt(
            id: id, createdAt: Date(), mode: checked.mode,
            sourceRelative: originalSource, targetRelative: originalTarget,
            resultName: name, files: checked.expectedFiles, state: .pending
        )
        var journalWritten = false
        do {
            for file in checked.expectedFiles {
                let parts = try relativeParts(file.path)
                let origin = sourceNames.contains(file.path) ? checked.source : checked.target
                let from = try readableSource(append(parts, to: origin), root: origin)
                let into = append(parts, to: payload)
                try fm.createDirectory(
                    at: into.deletingLastPathComponent(), withIntermediateDirectories: true
                )
                try fm.copyItem(at: from, to: into)
                let copied = try into.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard copied.isRegularFile == true,
                      Int64(copied.fileSize ?? -1) == file.bytes,
                      try hexHash(into) == file.sha256 else {
                    throw Failure.corruptResult
                }
            }
            // Recheck BOTH originals after copying: no silent stale file merges.
            let updated = try preview(
                source: checked.source, target: checked.target, mode: checked.mode
            )
            guard updated.sourceFiles == checked.sourceFiles,
                  updated.targetFiles == checked.targetFiles else {
                throw Failure.changedInput
            }
            try save(receipt)
            journalWritten = true
            guard !fm.fileExists(atPath: result.path) else { throw Failure.collision }
            try fm.moveItem(at: payload, to: result)
            guard try importedInventory(result) == checked.expectedFiles else {
                throw Failure.corruptResult
            }
            receipt.state = .complete
            try save(receipt)
            try? fm.removeItem(at: working)
            return receipt
        } catch {
            // The only user-visible mutation is a newly named result. Never
            // delete anything at a pre-existing source or target path.
            if journalWritten { try? recoverPending() }
            if !fm.fileExists(atPath: result.path) {
                try? fm.removeItem(at: working)
            }
            throw error
        }
    }
}
