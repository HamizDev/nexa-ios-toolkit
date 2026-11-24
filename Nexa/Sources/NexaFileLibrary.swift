import Foundation

struct ImportedEntry: Identifiable {
    var id: String { url.path }
    let url: URL
    let isDirectory: Bool
    let byteCount: Int64?
    let modifiedAt: Date?
    var name: String { url.lastPathComponent }
}

enum NexaFileSort: String, CaseIterable, Identifiable {
    case name, newest, largest
    var id: String { rawValue }

    func sorted(_ entries: [ImportedEntry]) -> [ImportedEntry] {
        entries.sorted { a, b in
            switch self {
            case .name: break
            case .newest:
                let left = a.modifiedAt ?? .distantPast
                let right = b.modifiedAt ?? .distantPast
                if left != right { return left > right }
            case .largest:
                // Folder sizes are intentionally unknown, not a recursive estimate.
                let left = a.byteCount ?? -1
                let right = b.byteCount ?? -1
                if left != right { return left > right }
            }
            let order = a.name.localizedStandardCompare(b.name)
            return order == .orderedSame ? a.id < b.id : order == .orderedAscending
        }
    }
}

enum NexaFileLibrary {
    enum Failure: LocalizedError {
        case outsideRoot, invalidItem, noSelection, duplicateSelection
        var errorDescription: String? {
            switch self {
            case .outsideRoot: return "Item is outside the current library."
            case .invalidItem: return "Item is hidden, unavailable, or not a regular file or directory."
            case .noSelection: return "Select at least one item."
            case .duplicateSelection: return "Duplicate selection."
            }
        }
    }

    struct Removal {
        var removed = 0
        var failures: [String] = []
    }

    private static let keys: Set<URLResourceKey> = [
        .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentModificationDateKey
    ]

    static func requireRoot(_ root: URL) throws {
        guard root.isFileURL else { throw Failure.outsideRoot }
        let flags = try URL(fileURLWithPath: root.path).resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard flags.isDirectory == true, flags.isSymbolicLink != true else { throw Failure.invalidItem }
    }

    static func entry(_ url: URL, root: URL, archivesOnly: Bool = false) throws -> ImportedEntry {
        let target = url.standardizedFileURL
        let base = root.standardizedFileURL
        guard url.isFileURL, target.deletingLastPathComponent().path == base.path else { throw Failure.outsideRoot }
        guard !target.lastPathComponent.hasPrefix(".") else { throw Failure.invalidItem }
        try requireRoot(base)
        let flags = try URL(fileURLWithPath: target.path).resourceValues(forKeys: keys)
        guard flags.isSymbolicLink != true, flags.isDirectory == true || flags.isRegularFile == true else { throw Failure.invalidItem }
        let isDirectory = flags.isDirectory == true
        if archivesOnly && (isDirectory || target.pathExtension.lowercased() != "zip") { throw Failure.invalidItem }
        return ImportedEntry(url: target, isDirectory: isDirectory,
                             byteCount: isDirectory ? nil : flags.fileSize.map(Int64.init),
                             modifiedAt: flags.contentModificationDate)
    }

    static func list(root: URL, archivesOnly: Bool = false) throws -> [ImportedEntry] {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try requireRoot(root)
        return NexaFileSort.name.sorted(try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles])
            .compactMap { try? entry($0, root: root, archivesOnly: archivesOnly) })
    }

    // Preflight every selection before a batch can mutate anything.
    static func selection(_ urls: [URL], root: URL, archivesOnly: Bool = false) throws -> [ImportedEntry] {
        guard !urls.isEmpty else { throw Failure.noSelection }
        let entries = try urls.map { try entry($0, root: root, archivesOnly: archivesOnly) }
        guard Set(entries.map(\.id)).count == entries.count else { throw Failure.duplicateSelection }
        return entries
    }

    // Reject symlinks or unsupported file types anywhere inside a copied/imported tree.
    static func validateTree(_ root: URL) throws {
        var stack = [root]
        let fm = FileManager.default
        while let item = stack.popLast() {
            let flags = try URL(fileURLWithPath: item.path).resourceValues(forKeys: keys)
            guard flags.isSymbolicLink != true else { throw Failure.invalidItem }
            if flags.isDirectory == true {
                stack.append(contentsOf: try fm.contentsOfDirectory(at: item, includingPropertiesForKeys: Array(keys)))
            } else if flags.isRegularFile != true { throw Failure.invalidItem }
        }
    }

    // The caller must hold the document picker's security-scoped access for source.
    static func copyImport(_ source: URL, root: URL) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try requireRoot(root)
        try validateTree(source)
        let token = UUID().uuidString
        let staging = root.appendingPathComponent(".pending-" + token)
        let destination = root.appendingPathComponent(token + "_" + source.lastPathComponent)
        defer { try? fm.removeItem(at: staging) }
        try fm.copyItem(at: source, to: staging)
        try validateTree(staging)
        try fm.moveItem(at: staging, to: destination)
        return destination
    }

    // Permanent deletion applies only to explicitly selected app-local copies.
    // A failed preflight changes nothing; later I/O failures are reported individually.
    static func remove(_ urls: [URL], root: URL, archivesOnly: Bool = false) throws -> Removal {
        let entries = try selection(urls, root: root, archivesOnly: archivesOnly)
        var result = Removal()
        for item in entries {
            do {
                let checked = try entry(item.url, root: root, archivesOnly: archivesOnly)
                try FileManager.default.removeItem(at: checked.url)
                result.removed += 1
            } catch { result.failures.append(item.name + ": " + error.localizedDescription) }
        }
        return result
    }
}
