import Foundation

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
            try FileManager.default.createDirectory(at: Self.importFolder, withIntermediateDirectories: true)
            let urls = try FileManager.default.contentsOfDirectory(
                at: Self.importFolder,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            entries = urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { url in
                    let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                    return ImportedEntry(url: url, isDirectory: values?.isDirectory ?? false)
                }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importURLs(_ urls: [URL]) {
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let destination = Self.importFolder
                    .appendingPathComponent(String(UUID().uuidString.prefix(8)) + "_" + url.lastPathComponent)
                try FileManager.default.copyItem(at: url, to: destination)
            } catch {
                errorMessage = "导入 \(url.lastPathComponent) 失败：\(error.localizedDescription)"
            }
        }
        refresh()
    }

    func delete(at offsets: IndexSet) {
        let selected = offsets.map { entries[$0].url }
        for url in selected {
            do { try FileManager.default.removeItem(at: url) }
            catch { errorMessage = error.localizedDescription }
        }
        refresh()
    }
}
