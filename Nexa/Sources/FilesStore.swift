import Foundation
import Combine

struct ImportedEntry: Identifiable {
    var id: String { url.path }
    let url: URL
    let isDirectory: Bool
    var name: String { url.lastPathComponent }
}

@MainActor
final class FilesStore: ObservableObject {
    @Published private(set) var entries: [ImportedEntry] = []
    @Published var errorMessage: String?
    @Published private(set) var operationBusy = false

    static var importFolder: URL { AppPaths.importFolder }

    init() { refresh() }

    func refresh() {
        do {
            try NexaBackupRestore.recoverIfNeeded()
            try FileManager.default.createDirectory(at: Self.importFolder, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(
                at: Self.importFolder,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            entries = urls
                .filter { (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { url in
                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                    return ImportedEntry(url: url, isDirectory: values?.isDirectory ?? false)
                }
        } catch { errorMessage = error.localizedDescription }
    }

    func importURLs(_ urls: [URL]) {
        guard !operationBusy, !urls.isEmpty else { return }
        operationBusy = true
        // Security-scoped access remains open for the duration of each staged
        // copy. File-provider I/O does not block the SwiftUI main actor.
        Task {
            let failures = await Task.detached(priority: .userInitiated) { () -> [String] in
                var problems: [String] = []
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    do {
                        _ = try NexaLocalFiles.importSelected(url)
                    } catch {
                        problems.append("Import \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                    if access { url.stopAccessingSecurityScopedResource() }
                }
                return problems
            }.value
            operationBusy = false
            if !failures.isEmpty { errorMessage = failures.joined(separator: "\n") }
            refresh()
        }
    }

    func createFolder(_ name: String) {
        do { _ = try NexaLocalFiles.createFolder(in: Self.importFolder, name: name) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }

    func rename(_ entry: ImportedEntry, to name: String) {
        do { _ = try NexaLocalFiles.rename(entry.url, to: name) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }

    func move(_ entry: ImportedEntry, into folder: URL) {
        do { _ = try NexaLocalFiles.move(entry.url, into: folder) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }

    func duplicate(_ entry: ImportedEntry) {
        guard !operationBusy else { return }
        operationBusy = true
        let original = entry.url
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try NexaLocalFiles.duplicate(original)
                }.value
            } catch {
                errorMessage = error.localizedDescription
            }
            operationBusy = false
            refresh()
        }
    }

    func remove(_ entry: ImportedEntry) {
        do { _ = try NexaLocalFiles.trash(entry.url) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }
}
