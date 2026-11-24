import Foundation

// Nexa-owned code for explicitly imported plist copies. No system paths or private APIs.
enum NexaLocalFiles {
    static func checked(_ url: URL, inside root: URL, directory: Bool = false) throws -> URL {
        let base = root.standardizedFileURL
        let target = url.standardizedFileURL
        let prefix = base.pathComponents
        let components = target.pathComponents
        guard url.isFileURL, root.isFileURL, components.count > prefix.count,
              Array(components.prefix(prefix.count)) == prefix else { throw NexaPlistHistory.Failure.outsideImports }
        try require(base, directory: true)
        var current = base
        let tail = components.dropFirst(prefix.count)
        for (index, part) in tail.enumerated() {
            let isLast = index == tail.count - 1
            current = current.appendingPathComponent(part, isDirectory: !isLast || directory)
            try require(current, directory: !isLast || directory)
        }
        return current
    }

    static func require(_ url: URL, directory: Bool) throws {
        // Construct a fresh URL so cached resource flags are not reused.
        let fresh = URL(fileURLWithPath: url.path)
        let flags = try fresh.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard flags.isSymbolicLink != true,
              directory ? flags.isDirectory == true : flags.isRegularFile == true else {
            throw NexaPlistHistory.Failure.invalidFile
        }
    }
}

struct NexaPlistHistory {
    enum Reason: String, Codable { case edit, restore }

    struct Record: Codable, Identifiable {
        let id: UUID
        let sourcePath: String
        let createdAt: Date
        let byteCount: Int
        let reason: Reason
    }

    enum Failure: LocalizedError {
        case outsideImports, invalidFile, tooLarge, invalidPlist, stale, invalidSnapshot, unchanged

        var errorDescription: String? { message(in: "en") }

        func message(in language: String) -> String {
            let en = language == "en"
            switch self {
            case .outsideImports: return en ? "Only imported copies can be edited." : "仅允许编辑已导入的副本。"
            case .invalidFile: return en ? "Invalid file or symbolic link." : "文件无效或包含符号链接。"
            case .tooLarge: return en ? "Property lists must be at most 16 MB." : "属性列表不能超过 16 MB。"
            case .invalidPlist: return en ? "Expected a dictionary property list." : "需要字典类型的属性列表。"
            case .stale: return en ? "The file changed. Reload before editing or restoring." : "文件已发生变化，请重新加载后再编辑或恢复。"
            case .invalidSnapshot: return en ? "This history record is invalid or belongs to another file." : "历史记录无效或属于其他文件。"
            case .unchanged: return en ? "The file already contains this version." : "当前文件已是该版本。"
            }
        }
    }

    static let sizeLimit = 16 * 1024 * 1024
    private static let metadataLimit = 64 * 1024
    let importRoot: URL
    let historyRoot: URL
    private let fm = FileManager.default

    func read(_ file: URL) throws -> Data {
        let target = try targetFile(file)
        let data = try boundedRead(target, limit: Self.sizeLimit)
        try validatePlist(data)
        return data
    }

    func records(for file: URL) throws -> [Record] {
        let path = try relativePath(file)
        guard fm.fileExists(atPath: historyRoot.path) else { return [] }
        try NexaLocalFiles.require(historyRoot, directory: true)
        let folders = try fm.contentsOfDirectory(at: historyRoot, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return folders.compactMap { folder -> Record? in
            guard let id = UUID(uuidString: folder.lastPathComponent),
                  let record = try? record(with: id), record.sourcePath == path else { return nil }
            return record
        }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func replace(_ file: URL, expected: Data, with replacement: Data, reason: Reason = .edit) throws -> Record {
        let target = try targetFile(file)
        try validatePlist(replacement)
        let current = try read(target)
        guard current == expected else { throw Failure.stale }
        guard current != replacement else { throw Failure.unchanged }
        let snapshot = try preserve(current, sourcePath: relativePath(target), reason: reason)
        // A snapshot exists before the write. Refuse stale contents rather than overwriting them.
        let checked = try targetFile(target)
        guard try read(checked) == current else { throw Failure.stale }
        try replacement.write(to: checked, options: .atomic)
        return snapshot
    }

    @discardableResult
    func restore(_ recordID: UUID, to file: URL, expected: Data) throws -> Record {
        let path = try relativePath(file)
        let item = try record(with: recordID)
        guard item.sourcePath == path else { throw Failure.invalidSnapshot }
        let folder = historyRoot.appendingPathComponent(recordID.uuidString, isDirectory: true)
        let payload = folder.appendingPathComponent("original.plist")
        try NexaLocalFiles.require(payload, directory: false)
        let data = try boundedRead(payload, limit: Self.sizeLimit)
        guard data.count == item.byteCount else { throw Failure.invalidSnapshot }
        return try replace(file, expected: expected, with: data, reason: .restore)
    }

    private func targetFile(_ file: URL) throws -> URL {
        guard file.pathExtension.lowercased() == "plist" else { throw Failure.invalidFile }
        return try NexaLocalFiles.checked(file, inside: importRoot)
    }

    private func relativePath(_ file: URL) throws -> String {
        let target = try targetFile(file)
        return target.pathComponents.dropFirst(importRoot.standardizedFileURL.pathComponents.count).joined(separator: "/")
    }

    private func preserve(_ data: Data, sourcePath: String, reason: Reason) throws -> Record {
        try fm.createDirectory(at: historyRoot, withIntermediateDirectories: true)
        try NexaLocalFiles.require(historyRoot, directory: true)
        let item = Record(id: UUID(), sourcePath: sourcePath, createdAt: Date(), byteCount: data.count, reason: reason)
        let staging = historyRoot.appendingPathComponent(".pending-" + item.id.uuidString, isDirectory: true)
        let destination = historyRoot.appendingPathComponent(item.id.uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        let metadata = try JSONEncoder().encode(item)
        guard metadata.count <= Self.metadataLimit else { throw Failure.invalidSnapshot }
        try data.write(to: staging.appendingPathComponent("original.plist"), options: .atomic)
        try metadata.write(to: staging.appendingPathComponent("record.json"), options: .atomic)
        try fm.moveItem(at: staging, to: destination)
        return item
    }

    private func record(with id: UUID) throws -> Record {
        try NexaLocalFiles.require(historyRoot, directory: true)
        let folder = historyRoot.appendingPathComponent(id.uuidString, isDirectory: true)
        try NexaLocalFiles.require(folder, directory: true)
        let metadata = folder.appendingPathComponent("record.json")
        try NexaLocalFiles.require(metadata, directory: false)
        let item = try JSONDecoder().decode(Record.self, from: boundedRead(metadata, limit: Self.metadataLimit))
        guard item.id == id, item.byteCount >= 0, item.byteCount <= Self.sizeLimit else { throw Failure.invalidSnapshot }
        return item
    }

    private func validatePlist(_ data: Data) throws {
        guard data.count <= Self.sizeLimit else { throw Failure.tooLarge }
        guard (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) is [String: Any] else {
            throw Failure.invalidPlist
        }
    }

    private func boundedRead(_ url: URL, limit: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var result = Data()
        while result.count <= limit {
            guard let chunk = try handle.read(upToCount: min(64 * 1024, limit + 1 - result.count)), !chunk.isEmpty else { break }
            result.append(chunk)
        }
        guard result.count <= limit else { throw Failure.tooLarge }
        return result
    }
}
