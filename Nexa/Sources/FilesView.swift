import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject private var language: NexaLanguage
    @StateObject private var store = FilesStore()
    @State private var importSheet = false
    @State private var archiveURL: URL?
    @State private var archiveBusy = false
    @State private var archiveNotice: String?
    @State private var search = ""

    private var visibleEntries: [ImportedEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? store.entries : store.entries.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(title: language.t("files.title"), subtitle: language.t("files.subtitle"))
                    NexaCard {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(language.t("files.access"))
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaActionButton(title: language.t("files.import"), symbol: "plus") {
                        importSheet = true
                    }
                    HStack(spacing: 12) {
                        Button { createArchive() } label: {
                            Label(language.code == "en" ? "Create ZIP" : "打包为 ZIP", systemImage: "archivebox")
                        }
                        .buttonStyle(.bordered)
                        .disabled(archiveBusy || store.entries.isEmpty)
                        if let archiveURL {
                            ShareLink(item: archiveURL) {
                                Label(language.code == "en" ? "Share ZIP" : "分享 ZIP", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if archiveBusy {
                        ProgressView().tint(NexaPalette.mint)
                    }
                    if let archiveNotice {
                        Text(archiveNotice)
                            .font(.footnote)
                            .foregroundStyle(NexaPalette.muted)
                    }
                    if !store.entries.isEmpty {
                        TextField(language.code == "en" ? "Search file names" : "搜索文件名", text: $search)
                            .textFieldStyle(.roundedBorder)
                    }
                    if store.entries.isEmpty {
                        NexaCard {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 34))
                                    .foregroundStyle(NexaPalette.blue)
                                Text(language.t("files.empty")).font(.headline)
                                Text(language.t("files.empty.detail"))
                                    .font(.subheadline)
                                    .foregroundStyle(NexaPalette.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else if visibleEntries.isEmpty {
                        NexaCard {
                            Text(language.code == "en" ? "No matching files." : "没有匹配的文件。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    } else {
                        NexaCard {
                            VStack(spacing: 0) {
                                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                                    HStack(spacing: 11) {
                                        NavigationLink(destination: entry.isDirectory ? AnyView(LocalFolderView(folder: entry.url)) : AnyView(FileInspectorView(file: entry.url))) {
                                            HStack(spacing: 11) {
                                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                                    .foregroundStyle(entry.isDirectory ? NexaPalette.violet : NexaPalette.blue)
                                                    .frame(width: 28)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(entry.name).font(.subheadline.weight(.medium)).lineLimit(2)
                                                    Text(language.t(entry.isDirectory ? "files.folder" : "files.file"))
                                                        .font(.caption).foregroundStyle(NexaPalette.muted)
                                                }
                                                Spacer(minLength: 0)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        ShareLink(item: entry.url) {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundStyle(NexaPalette.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 10)
                                    .contextMenu {
                                        ShareLink(item: entry.url) { Label(language.t("common.share"), systemImage: "square.and.arrow.up") }
                                        Button(role: .destructive) { store.remove(entry) } label: { Label(language.t("files.delete"), systemImage: "trash") }
                                    }
                                    if index + 1 < visibleEntries.count { Divider().overlay(.white.opacity(0.07)) }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { importSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .fileImporter(isPresented: $importSheet, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): store.importURLs(urls)
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .alert(language.t("common.error"), isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func createArchive() {
        archiveBusy = true
        archiveNotice = nil
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaZipManager.createImportedArchive()
                }.value
                archiveURL = result.file
                archiveNotice = language.code == "en"
                    ? "Archive ready. Skipped entries: \(result.skipped)."
                    : "ZIP 已创建，跳过条目：\(result.skipped)。"
            } catch {
                store.errorMessage = error.localizedDescription
            }
            archiveBusy = false
        }
    }
}
