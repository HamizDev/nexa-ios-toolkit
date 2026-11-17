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
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let destination = Self.importFolder
                    .appendingPathComponent(String(UUID().uuidString.prefix(8)) + "_" + url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: destination)
            } catch { errorMessage = "Import \(url.lastPathComponent): \(error.localizedDescription)" }
        }
        refresh()
    }

    func remove(_ entry: ImportedEntry) {
        do { try FileManager.default.removeItem(at: entry.url) }
        catch { errorMessage = error.localizedDescription }
        refresh()
    }
}
