import Foundation

@main
enum FileLibraryRegression {
    static func require(_ value: Bool, _ message: String) throws {
        if !value { throw NSError(domain: "FileLibraryRegression", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ message: String, _ work: () throws -> Void) throws {
        do { try work() } catch { return }
        try require(false, message)
    }
    static func main() throws {
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("NexaLibrary-" + UUID().uuidString)
        defer { try? fm.removeItem(at: temp) }
        let root = temp.appendingPathComponent("Imports", isDirectory: true)
        let archives = temp.appendingPathComponent("Archives", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: archives, withIntermediateDirectories: true)
        let outside = temp.appendingPathComponent("outside.txt")
        let a = root.appendingPathComponent("file2.txt")
        let b = root.appendingPathComponent("file10.txt")
        let folder = root.appendingPathComponent("Folder", isDirectory: true)
        try Data("outside".utf8).write(to: outside)
        try Data([1]).write(to: a)
        try Data([1, 2, 3]).write(to: b)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: a.path)
        try fm.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: b.path)
        try fm.createDirectory(at: folder, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("link")
        try fm.createSymbolicLink(at: link, withDestinationURL: outside)
        try Data().write(to: root.appendingPathComponent(".pending-test"))
        let list = try NexaFileLibrary.list(root: root)
        try require(list.count == 3 && list.contains { $0.isDirectory && $0.byteCount == nil }, "Hidden/symlink entries or incorrect folder size")
        let names = NexaFileSort.name.sorted(list).filter { !$0.isDirectory }.map(\.name)
        try require(names == ["file2.txt", "file10.txt"], "Natural name sort failed")
        try require(NexaFileSort.largest.sorted(list).first?.url == b, "Size sort failed")
        let dated = NexaFileSort.newest.sorted(list).filter { !$0.isDirectory }
        try require(dated.first?.url == b, "Date sort failed")
        try rejects("Out-of-root selection allowed") { _ = try NexaFileLibrary.remove([a, outside], root: root) }
        try rejects("Duplicate selection allowed") { _ = try NexaFileLibrary.selection([a, a], root: root) }
        try rejects("Symbolic-link selection allowed") { _ = try NexaFileLibrary.remove([a, link], root: root) }
        try require(fm.fileExists(atPath: a.path) && fm.fileExists(atPath: outside.path), "Failed preflight deleted files")
        let copied = try NexaFileLibrary.copyImport(outside, root: root)
        let bytes = try Data(contentsOf: copied)
        try require(bytes == Data("outside".utf8), "Import changed bytes")
        try rejects("Imported symlink") { _ = try NexaFileLibrary.copyImport(link, root: root) }
        let unsafeFolder = temp.appendingPathComponent("Unsafe", isDirectory: true)
        try fm.createDirectory(at: unsafeFolder, withIntermediateDirectories: false)
        try fm.createSymbolicLink(at: unsafeFolder.appendingPathComponent("nested-link"), withDestinationURL: outside)
        try rejects("Nested symlink imported") { _ = try NexaFileLibrary.copyImport(unsafeFolder, root: root) }
        let archive = archives.appendingPathComponent("Nexa.zip")
        let unrelated = archives.appendingPathComponent("notes.txt")
        try Data([1]).write(to: archive)
        try Data([2]).write(to: unrelated)
        let archiveList = try NexaFileLibrary.list(root: archives, archivesOnly: true)
        try require(archiveList.map(\.url) == [archive], "Archive list accepted other types")
        try rejects("Non-archive delete allowed") { _ = try NexaFileLibrary.remove([unrelated], root: archives, archivesOnly: true) }
        let removed = try NexaFileLibrary.remove([a, b], root: root)
        try require(removed.removed == 2 && removed.failures.isEmpty && !fm.fileExists(atPath: a.path) && fm.fileExists(atPath: outside.path), "Batch deletion incorrect")
        let removedZip = try NexaFileLibrary.remove([archive], root: archives, archivesOnly: true)
        try require(removedZip.removed == 1 && fm.fileExists(atPath: unrelated.path), "Archive removal incorrect")
        print("PASS: sorting, metadata, hidden/symlink filtering, selection preflight, staged import, batch removal and archive isolation")
    }
}
