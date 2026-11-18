import Foundation

/// File operations strictly limited to files that the user imported into Nexa.
///
/// All paths are validated relative to Documents/Imports. Existing symlinks,
/// path traversal, moves into descendants, and name collisions are rejected.
/// Deletion is a recoverable move to private Application Support trash.
enum NexaLocalFiles {
    enum FileError: LocalizedError {
        case invalidName, outsideImports, symlink, notDirectory
        case alreadyExists, cannotMoveIntoSelf, missingFile
        case invalidTrashRecord

        var errorDescription: String? {
            switch self {
            case .invalidName: return "Invalid file name. Do not use separators, hidden names, or dot components."
            case .outsideImports: return "File access is limited to Nexa's imported files."
            case .symlink: return "Symbolic links are not supported for file operations."
            case .notDirectory: return "The selected destination is not a folder."
            case .alreadyExists: return "A file or folder with the same name already exists."
            case .cannotMoveIntoSelf: return "A folder cannot be moved into itself or its children."
            case .missingFile: return "The source file no longer exists."
            case .invalidTrashRecord: return "This deleted item cannot be safely restored."
            }
        }
    }

    struct TrashRecord: Identifiable, Codable {
        let id: UUID
        let originalRelativePath: String
        let name: String
        let deletedAt: Date
    }

    private static let lock = NSRecursiveLock()
    private static var fm: FileManager { .default }

    static var trashRoot: URL {
        #if NEXA_LOCAL_TEST
        if let root = ProcessInfo.processInfo.environment["NEXA_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root, isDirectory: true)
                .appendingPathComponent("ApplicationSupport/Nexa/FileTrash", isDirectory: true)
        }
        #endif
        return fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa/FileTrash", isDirectory: true)
    }

    private static func checkName(_ name: String) throws {
        guard name == name.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty, !name.hasPrefix("."), name != "..",
              name.utf8.count <= 240,
              !name.contains("/"), !name.contains("\\"),
              !name.contains("\0"), !name.contains(":") else {
            throw FileError.invalidName
        }
    }

    private static func checkParts(_ relative: String) throws -> [String] {
        let parts = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !relative.isEmpty, !relative.hasPrefix("/"),
              parts.allSatisfy({
                  !$0.isEmpty && $0 != "." && $0 != ".." &&
                  !$0.contains("\\") && !$0.contains("\0")
              }) else { throw FileError.outsideImports }
        return parts
    }

    /// Resolve both paths to avoid the /var versus /private/var alias on macOS.
    /// Then independently examine the original input's ancestors to reject
    /// symbolic links before allowing a mutation.
    private static func safe(_ url: URL, allowRoot: Bool = false) throws -> URL {
        let root = AppPaths.importFolder.standardizedFileURL
        let candidate = url.standardizedFileURL
        guard !url.pathComponents.contains("..") else { throw FileError.outsideImports }

        let canonicalRoot = root.resolvingSymlinksInPath().standardizedFileURL
        let canonical = candidate.resolvingSymlinksInPath().standardizedFileURL
        let r = canonicalRoot.pathComponents
        let c = canonical.pathComponents
        guard c.starts(with: r), allowRoot ? c.count >= r.count : c.count > r.count else {
            throw FileError.outsideImports
        }
        // Reject symlinks even if their target happens to stay inside Imports.
        var cursor = candidate
        while cursor.pathComponents.count >= root.pathComponents.count {
            if (try? cursor.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                throw FileError.symlink
            }
            if cursor.pathComponents.count == root.pathComponents.count { break }
            cursor.deleteLastPathComponent()
        }
        return canonical
    }

    private static func directory(_ url: URL) throws -> URL {
        let folder = try safe(url, allowRoot: true)
        let v = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard v.isSymbolicLink != true else { throw FileError.symlink }
        guard v.isDirectory == true else { throw FileError.notDirectory }
        return folder
    }

    private static func item(_ url: URL) throws -> URL {
        let source = try safe(url)
        guard fm.fileExists(atPath: source.path) else { throw FileError.missingFile }
        return source
    }

    private static func rejectNestedLinks(_ root: URL) throws {
        if (try root.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            throw FileError.symlink
        }
        guard (try root.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return }
        let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])
        while let child = en?.nextObject() as? URL {
            if (try child.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
                throw FileError.symlink
            }
        }
    }

    private static func destination(in folder: URL, name: String) throws -> URL {
        try checkName(name)
        let root = try directory(folder)
        let result = root.appendingPathComponent(name)
        _ = try safe(result)
        guard !fm.fileExists(atPath: result.path) else { throw FileError.alreadyExists }
        return result
    }

    static func list(in folder: URL) throws -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        let parent = try directory(folder)
        return try fm.contentsOfDirectory(
            at: parent, includingPropertiesForKeys: [.isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ).filter {
            (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true
        }.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    /// Only existing imported directories may be chosen as move targets.
    /// Excludes the original parent and moving a folder into its own subtree.
    /// The list is bounded so a huge imported tree cannot fill the picker.
    static func availableMoveFolders(for source: URL, limit: Int = 200) throws -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        let old = try item(source)
        let oldIsFolder = (try old.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
        let originalParent = old.deletingLastPathComponent()
        let root = try directory(AppPaths.importFolder)
        var queue: [URL] = [root]
        var folders: [URL] = []
        let maximum = min(500, max(1, limit))
        while !queue.isEmpty && folders.count < maximum {
            let candidate = queue.removeFirst()
            if oldIsFolder && candidate.pathComponents.starts(with: old.pathComponents) {
                continue
            }
            if candidate != originalParent {
                folders.append(candidate)
            }
            let entries = try list(in: candidate)
            for child in entries {
                if (try child.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true {
                    queue.append(child.resolvingSymlinksInPath().standardizedFileURL)
                }
            }
        }
        return folders
    }

    /// Validate an externally selected, security-scoped source before copying
    /// into Nexa. This does not grant access to other app sandboxes.
    static func validateUserImport(_ source: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        try rejectNestedLinks(source)
        let flags = try source.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
        guard flags.isDirectory == true || flags.isRegularFile == true else {
            throw FileError.missingFile
        }
    }

    static func createFolder(in folder: URL, name: String) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let target = try destination(in: folder, name: name)
        try fm.createDirectory(at: target, withIntermediateDirectories: false)
        return target
    }

    static func rename(_ source: URL, to newName: String) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let old = try item(source)
        if old.lastPathComponent == newName { return old }
        try rejectNestedLinks(old)
        let target = try destination(in: old.deletingLastPathComponent(), name: newName)
        try fm.moveItem(at: old, to: target)
        return target
    }

    static func duplicate(_ source: URL) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let old = try item(source)
        try rejectNestedLinks(old)
        let parent = old.deletingLastPathComponent()
        let isFolder = (try old.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true
        let ext = isFolder ? "" : old.pathExtension
        let stem = ext.isEmpty ? old.lastPathComponent : old.deletingPathExtension().lastPathComponent
        for number in 1...999 {
            let candidateName = stem + (number == 1 ? " copy" : " copy \(number)") +
                (ext.isEmpty ? "" : "." + ext)
            let candidate = parent.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) {
                let target = try destination(in: parent, name: candidateName)
                try fm.copyItem(at: old, to: target)
                return target
            }
        }
        throw FileError.alreadyExists
    }

    static func move(_ source: URL, into folder: URL) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let old = try item(source)
        try rejectNestedLinks(old)
        let parent = try directory(folder)
        if parent.pathComponents.starts(with: old.pathComponents) {
            throw FileError.cannotMoveIntoSelf
        }
        let target = try destination(in: parent, name: old.lastPathComponent)
        try fm.moveItem(at: old, to: target)
        return target
    }

    private static func trashFolder(_ id: UUID) -> URL {
        trashRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }
    private static func stored(_ record: TrashRecord) -> URL {
        trashFolder(record.id).appendingPathComponent("Payload")
    }
    private static func metadata(_ id: UUID) -> URL {
        trashFolder(id).appendingPathComponent("record.json")
    }

    @discardableResult
    static func trash(_ source: URL) throws -> TrashRecord {
        lock.lock()
        defer { lock.unlock() }
        let old = try item(source)
        try rejectNestedLinks(old)
        let rootParts = AppPaths.importFolder.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let parts = old.pathComponents
        guard parts.starts(with: rootParts), parts.count > rootParts.count else {
            throw FileError.outsideImports
        }
        let relative = parts.dropFirst(rootParts.count).joined(separator: "/")
        let record = TrashRecord(id: UUID(), originalRelativePath: relative,
                                 name: old.lastPathComponent, deletedAt: Date())
        let holder = trashFolder(record.id)
        try fm.createDirectory(at: holder, withIntermediateDirectories: true)
        do {
            try JSONEncoder().encode(record).write(to: metadata(record.id), options: .atomic)
            try fm.moveItem(at: old, to: stored(record))
        } catch {
            try? fm.removeItem(at: holder)
            throw error
        }
        return record
    }

    static func trashItems() throws -> [TrashRecord] {
        lock.lock()
        defer { lock.unlock() }
        try fm.createDirectory(at: trashRoot, withIntermediateDirectories: true)
        let folders = try fm.contentsOfDirectory(
            at: trashRoot, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        return folders.compactMap { folder in
            guard (try? folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true,
                  let id = UUID(uuidString: folder.lastPathComponent),
                  let raw = try? Data(contentsOf: metadata(id)),
                  let record = try? JSONDecoder().decode(TrashRecord.self, from: raw),
                  record.id == id,
                  (try? checkParts(record.originalRelativePath)) != nil,
                  fm.fileExists(atPath: stored(record).path) else { return nil }
            return record
        }.sorted { $0.deletedAt > $1.deletedAt }
    }

    static func restore(_ record: TrashRecord) throws -> URL {
        lock.lock()
        defer { lock.unlock() }
        let confirmed = try validatedTrashRecord(record)
        let parts = try checkParts(confirmed.originalRelativePath)
        var target = AppPaths.importFolder
        for part in parts { target.appendPathComponent(part) }
        _ = try safe(target)
        guard !fm.fileExists(atPath: target.path) else { throw FileError.alreadyExists }

        let parent = target.deletingLastPathComponent()
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        _ = try directory(parent)
        try fm.moveItem(at: stored(confirmed), to: target)
        try fm.removeItem(at: trashFolder(record.id))
        return target
    }

    static func permanentlyDelete(_ record: TrashRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        _ = try validatedTrashRecord(record)
        try fm.removeItem(at: trashFolder(record.id))
    }

    private static func validatedTrashRecord(_ record: TrashRecord) throws -> TrashRecord {
        let path = metadata(record.id)
        guard let raw = try? Data(contentsOf: path),
              let confirmed = try? JSONDecoder().decode(TrashRecord.self, from: raw),
              confirmed.id == record.id,
              confirmed.originalRelativePath == record.originalRelativePath,
              confirmed.name == record.name,
              (try? checkParts(confirmed.originalRelativePath)) != nil,
              fm.fileExists(atPath: stored(confirmed).path) else {
            throw FileError.invalidTrashRecord
        }
        return confirmed
    }
}
