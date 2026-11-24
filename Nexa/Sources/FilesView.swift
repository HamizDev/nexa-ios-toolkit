import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject private var language: NexaLanguage
    @StateObject private var store = FilesStore()
    @State private var importSheet = false
    @State private var archiveBusy = false
    @State private var archiveNotice: String?
    @State private var search = ""
    @State private var sort = NexaFileSort.name
    @State private var selecting = false
    @State private var selection: Set<String> = []
    @State private var showArchives = false
    @State private var pendingDeletion: Deletion?

    private struct Deletion {
        let urls: [URL]
        let archivesOnly: Bool
    }

    private var busy: Bool { archiveBusy || store.busy }
    private var en: Bool { language.code == "en" }
    private var visibleEntries: [ImportedEntry] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? store.entries : store.entries.filter { $0.name.localizedStandardContains(query) }
        return sort.sorted(matches)
    }
    private var selectedEntries: [ImportedEntry] { store.entries.filter { selection.contains($0.id) } }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(title: language.t("files.title"), subtitle: language.t("files.subtitle"))
                    NexaCard {
                        Label(language.t("files.access"), systemImage: "lock.shield")
                            .font(.footnote).foregroundStyle(NexaPalette.muted)
                    }
                    NexaActionButton(title: language.t("files.import"), symbol: "plus") { importSheet = true }
                        .disabled(busy)
                    HStack {
                        Button { createArchive(urls: nil) } label: {
                            Label(en ? "ZIP all" : "全部打包", systemImage: "archivebox")
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy || store.entries.isEmpty || selecting)
                        Button { showArchives = true } label: {
                            Label(en ? "Archives" : "归档历史", systemImage: "tray.full")
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy)
                    }
                    if busy { ProgressView().tint(NexaPalette.mint) }
                    if let archiveNotice {
                        Text(archiveNotice).font(.footnote).foregroundStyle(NexaPalette.muted)
                    }
                    if !store.entries.isEmpty {
                        controls
                    }
                    if store.entries.isEmpty {
                        NexaCard {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 34)).foregroundStyle(NexaPalette.blue)
                                Text(language.t("files.empty")).font(.headline)
                                Text(language.t("files.empty.detail"))
                                    .font(.subheadline).foregroundStyle(NexaPalette.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    } else if visibleEntries.isEmpty {
                        NexaCard {
                            Text(en ? "No matching files." : "没有匹配的文件。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    } else {
                        NexaCard {
                            VStack(spacing: 0) {
                                ForEach(Array(visibleEntries.enumerated()), id: \.element.id) { index, entry in
                                    if selecting {
                                        Button { toggle(entry.id) } label: {
                                            HStack {
                                                Image(systemName: selection.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(NexaPalette.mint)
                                                fileLabel(entry)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(busy)
                                        .accessibilityAddTraits(selection.contains(entry.id) ? .isSelected : [])
                                        .padding(.vertical, 10)
                                    } else {
                                        HStack(spacing: 11) {
                                            NavigationLink(destination: entry.isDirectory ? AnyView(LocalFolderView(folder: entry.url)) : AnyView(FileInspectorView(file: entry.url))) {
                                                fileLabel(entry)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(busy)
                                            ShareLink(item: entry.url) {
                                                Image(systemName: "square.and.arrow.up").foregroundStyle(NexaPalette.blue)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(language.t("common.share"))
                                            .disabled(busy)
                                        }
                                        .padding(.vertical, 10)
                                        .contextMenu {
                                            ShareLink(item: entry.url) { Label(language.t("common.share"), systemImage: "square.and.arrow.up") }
                                                .disabled(busy)
                                            Button(role: .destructive) {
                                                pendingDeletion = Deletion(urls: [entry.url], archivesOnly: false)
                                            } label: { Label(language.t("files.delete"), systemImage: "trash") }
                                            .disabled(busy)
                                        }
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
        .onAppear { store.refresh(); reconcileSelection() }
        .onChange(of: store.entries.map(\.id)) { _, _ in reconcileSelection() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { importSheet = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(language.t("files.import"))
                    .disabled(busy)
            }
        }
        .fileImporter(isPresented: $importSheet, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task { await store.importURLs(urls) }
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showArchives) {
            NavigationStack {
                NexaArchivesView(store: store)
            }
            .environmentObject(language)
        }
        .confirmationDialog(en ? "Delete selected copies?" : "删除选中的副本？", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible, presenting: pendingDeletion) { deletion in
            Button(en ? "Permanently delete" : "永久删除", role: .destructive) {
                pendingDeletion = nil
                remove(deletion)
            }
            Button(language.t("common.cancel"), role: .cancel) { pendingDeletion = nil }
        } message: { deletion in
            Text(en ? "\(deletion.urls.count) imported copies will be permanently removed, including folder contents. Original external files are unaffected." :
                 "将永久删除 \(deletion.urls.count) 个导入副本（包括文件夹内容），不会删除外部原始文件。")
        }
        .alert(language.t("common.error"), isPresented: Binding(
            get: { store.errorMessage != nil && !showArchives },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(en ? "Search file names" : "搜索文件名", text: $search)
                .textFieldStyle(.roundedBorder)
            HStack {
                Menu {
                    Picker(en ? "Sort by" : "排序方式", selection: $sort) {
                        Text(en ? "Name" : "名称").tag(NexaFileSort.name)
                        Text(en ? "Newest" : "最近修改").tag(NexaFileSort.newest)
                        Text(en ? "File size" : "文件大小").tag(NexaFileSort.largest)
                    }
                } label: { Label(en ? "Sort" : "排序", systemImage: "arrow.up.arrow.down") }
                Spacer()
                Button(selecting ? (en ? "Done" : "完成") : (en ? "Select" : "多选")) {
                    selecting.toggle()
                    selection.removeAll()
                }
                .disabled(busy)
            }
            if selecting {
                Text(en ? "\(selectedEntries.count) selected (including filtered items)" : "已选 \(selectedEntries.count) 项（含搜索隐藏项）")
                    .font(.caption).foregroundStyle(NexaPalette.muted)
                ViewThatFits(in: .horizontal) {
                    HStack { selectionActions }
                    VStack(alignment: .leading) { selectionActions }
                }
                ViewThatFits(in: .horizontal) {
                    HStack { batchActions }
                    VStack(alignment: .leading) { batchActions }
                }
            }
        }
    }

    @ViewBuilder private var selectionActions: some View {
        Button(en ? "Select visible" : "选择可见项") { selection.formUnion(visibleEntries.map(\.id)) }
            .disabled(busy || visibleEntries.isEmpty)
        Button(en ? "Clear selection" : "清空选择") { selection.removeAll() }
            .disabled(busy || selection.isEmpty)
    }

    @ViewBuilder private var batchActions: some View {
        Button {
            createArchive(urls: selectedEntries.map(\.url))
        } label: { Label(en ? "ZIP selected" : "打包选中项", systemImage: "archivebox") }
        .buttonStyle(.bordered)
        .disabled(busy || selectedEntries.isEmpty)
        Button(role: .destructive) {
            pendingDeletion = Deletion(urls: selectedEntries.map(\.url), archivesOnly: false)
        } label: { Label(en ? "Delete selected" : "删除选中项", systemImage: "trash") }
        .buttonStyle(.bordered)
        .disabled(busy || selectedEntries.isEmpty)
    }

    private func fileLabel(_ entry: ImportedEntry) -> some View {
        HStack(spacing: 11) {
            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(entry.isDirectory ? NexaPalette.violet : NexaPalette.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name).font(.subheadline.weight(.medium)).lineLimit(2)
                if let size = entry.byteCount {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption).foregroundStyle(NexaPalette.muted)
                } else {
                    Text(language.t("files.folder")).font(.caption).foregroundStyle(NexaPalette.muted)
                }
                if let date = entry.modifiedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2).foregroundStyle(NexaPalette.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func reconcileSelection() {
        selection.formIntersection(store.entries.map(\.id))
    }

    private func createArchive(urls: [URL]?) {
        guard !busy else { return }
        archiveBusy = true
        archiveNotice = nil
        Task {
            defer { archiveBusy = false }
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaZipManager.createImportedArchive(items: urls)
                }.value
                store.refresh()
                archiveNotice = en ? "ZIP saved to archive history. Skipped entries: \(result.skipped)." :
                    "ZIP 已存入归档历史，跳过条目：\(result.skipped)。"
            } catch { store.errorMessage = error.localizedDescription }
        }
    }

    private func remove(_ deletion: Deletion) {
        guard !busy else { return }
        Task {
            do {
                let result = try await store.remove(deletion.urls, archivesOnly: deletion.archivesOnly)
                archiveNotice = en ? "Deleted \(result.removed) copies." : "已删除 \(result.removed) 个副本。"
                if !result.failures.isEmpty { store.errorMessage = result.failures.joined(separator: "\n") }
            } catch { store.errorMessage = error.localizedDescription }
        }
    }
}

struct NexaArchivesView: View {
    @EnvironmentObject private var language: NexaLanguage
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FilesStore
    @State private var pending: ImportedEntry?

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    NexaHeader(title: en ? "Archives" : "归档历史",
                               subtitle: en ? "ZIP files created by Nexa" : "Nexa 创建的 ZIP 压缩包")
                    if store.archives.isEmpty {
                        NexaCard { Text(en ? "No saved archives." : "暂无归档。").foregroundStyle(NexaPalette.muted) }
                    }
                    ForEach(NexaFileSort.newest.sorted(store.archives)) { entry in
                        NexaCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(entry.name, systemImage: "archivebox.fill").font(.subheadline.weight(.medium))
                                if let size = entry.byteCount {
                                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                        .font(.caption).foregroundStyle(NexaPalette.muted)
                                }
                                if let date = entry.modifiedAt {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(NexaPalette.muted)
                                }
                                HStack {
                                    ShareLink(item: entry.url) { Label(language.t("common.share"), systemImage: "square.and.arrow.up") }
                                        .buttonStyle(.bordered)
                                    Button(role: .destructive) { pending = entry } label: {
                                        Label(en ? "Delete ZIP" : "删除归档", systemImage: "trash")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .disabled(store.busy)
                            }
                        }
                    }
                    if store.busy { ProgressView() }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Archives" : "归档")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(en ? "Done" : "完成") { dismiss() }.disabled(store.busy)
            }
        }
        .interactiveDismissDisabled(store.busy)
        .confirmationDialog(en ? "Delete this ZIP?" : "删除此 ZIP？", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        ), titleVisibility: .visible, presenting: pending) { entry in
            Button(en ? "Permanently delete" : "永久删除", role: .destructive) {
                pending = nil
                Task {
                    do {
                        let result = try await store.remove([entry.url], archivesOnly: true)
                        if !result.failures.isEmpty { store.errorMessage = result.failures.joined(separator: "\n") }
                    } catch { store.errorMessage = error.localizedDescription }
                }
            }
            Button(language.t("common.cancel"), role: .cancel) { pending = nil }
        } message: { _ in
            Text(en ? "Only the saved ZIP is removed. Imported source files are kept." : "仅删除已保存的 ZIP，保留导入的源文件。")
        }
        .alert(language.t("common.error"), isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
