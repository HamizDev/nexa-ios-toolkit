import Foundation
import Combine

@MainActor
final class FilesStore: ObservableObject {
    @Published private(set) var entries: [ImportedEntry] = []
    @Published private(set) var archives: [ImportedEntry] = []
    @Published var errorMessage: String?
    @Published private(set) var busy = false

    static var importFolder: URL { AppPaths.importFolder }

    init() { refresh() }

    func refresh() {
        do { entries = try NexaFileLibrary.list(root: Self.importFolder) }
        catch { entries = []; errorMessage = error.localizedDescription }
        do { archives = try NexaFileLibrary.list(root: AppPaths.archiveFolder, archivesOnly: true) }
        catch { archives = []; errorMessage = error.localizedDescription }
    }

    func importURLs(_ urls: [URL]) async {
        guard !busy else { return }
        busy = true
        defer { busy = false; refresh() }
        let root = Self.importFolder
        let failures = await Task.detached(priority: .userInitiated) {
            var failures: [String] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do { _ = try NexaFileLibrary.copyImport(url, root: root) }
                catch { failures.append(url.lastPathComponent + ": " + error.localizedDescription) }
            }
            return failures
        }.value
        if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
    }

    func remove(_ urls: [URL], archivesOnly: Bool) async throws -> NexaFileLibrary.Removal {
        guard !busy else { throw NexaFileLibrary.Failure.invalidItem }
        busy = true
        defer { busy = false; refresh() }
        let root = archivesOnly ? AppPaths.archiveFolder : Self.importFolder
        return try await Task.detached(priority: .userInitiated) {
            try NexaFileLibrary.remove(urls, root: root, archivesOnly: archivesOnly)
        }.value
    }
}
