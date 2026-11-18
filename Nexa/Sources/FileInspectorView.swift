import SwiftUI
import Foundation

/// Browse and manage only the copies inside Nexa's Documents/Imports tree.
/// Unsafe paths and symbolic links are rejected by NexaLocalFiles.
struct LocalFolderView: View {
    @EnvironmentObject private var language: NexaLanguage
    let folder: URL
    @State private var children: [URL] = []
    @State private var searchText = ""
    @State private var prompt: NexaFileNamePrompt?
    @State private var pendingTrash: URL?
    @State private var notice: String?
    @State private var busy = false

    private var en: Bool { language.code == "en" }

    private var visible: [URL] {
        guard !searchText.isEmpty else { return children }
        return children.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(en ? "Search this folder" : "搜索当前文件夹", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 10) {
                        Button {
                            prompt = NexaFileNamePrompt(titleZh: "新建文件夹",
                                                        titleEn: "New folder",
                                                        initialValue: "", target: nil)
                        } label: {
                            Label(en ? "New folder" : "新建文件夹", systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy)
                        Spacer()
                        Text(en ? "\(visible.count) items" : "\(visible.count) 项")
                            .font(.caption)
                            .foregroundStyle(NexaPalette.muted)
                    }
                    if busy {
                        ProgressView().tint(NexaPalette.mint)
                    }
                    if visible.isEmpty {
                        NexaCard {
                            Text(en ? "No files found." : "当前文件夹暂无文件。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    ForEach(visible, id: \.path) { url in
                        NexaCard {
                            HStack(spacing: 12) {
                                NavigationLink(destination:
                                    isFolder(url) ?
                                        AnyView(LocalFolderView(folder: url)) :
                                        AnyView(FileInspectorView(file: url))
                                ) {
                                    HStack(spacing: 10) {
                                        Image(systemName: isFolder(url) ? "folder.fill" : "doc.fill")
                                            .foregroundStyle(NexaPalette.blue)
                                        Text(url.lastPathComponent)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(NexaPalette.muted)
                                    }
                                }
                                .buttonStyle(.plain)
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundStyle(NexaPalette.blue)
                                }
                            }
                            .contextMenu {
                                Button {
                                    prompt = NexaFileNamePrompt(
                                        titleZh: "重命名", titleEn: "Rename",
                                        initialValue: url.lastPathComponent, target: url
                                    )
                                } label: {
                                    Label(en ? "Rename" : "重命名", systemImage: "pencil")
                                }
                                Button { duplicate(url) } label: {
                                    Label(en ? "Duplicate" : "复制副本", systemImage: "doc.on.doc")
                                }
                                Button(role: .destructive) { pendingTrash = url } label: {
                                    Label(en ? "Move to trash" : "移至回收站", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    NexaWeChatIdentityView(folder: folder)
                } label: {
                    Image(systemName: "person.text.rectangle")
                }
                .accessibilityLabel(
                    en ? "Inspect imported WeChat identity" : "检查已导入的微信账号身份"
                )
            }
        }
        .onAppear(perform: reload)
        .refreshable { reload() }
        .sheet(item: $prompt) { request in
            NexaFileNameSheet(request: request) { name in
                do {
                    if let target = request.target {
                        _ = try NexaLocalFiles.rename(target, to: name)
                    } else {
                        _ = try NexaLocalFiles.createFolder(in: folder, name: name)
                    }
                    reload()
                } catch { notice = error.localizedDescription }
            }
            .environmentObject(language)
        }
        .confirmationDialog(
            en ? "Move this file to Recently Deleted?" : "将此文件移至回收站？",
            isPresented: Binding(
                get: { pendingTrash != nil },
                set: { if !$0 { pendingTrash = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(en ? "Move to trash" : "移至回收站", role: .destructive) {
                if let selected = pendingTrash {
                    do {
                        _ = try NexaLocalFiles.trash(selected)
                        reload()
                    } catch { notice = error.localizedDescription }
                }
                pendingTrash = nil
            }
            Button(language.t("common.cancel"), role: .cancel) { pendingTrash = nil }
        } message: {
            Text(en ? "You can recover it from the Files tab." : "以后可以从文件页的“最近删除”恢复。")
        }
        .alert(en ? "File operations" : "文件操作", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    private func reload() {
        do { children = try NexaLocalFiles.list(in: folder) }
        catch { notice = error.localizedDescription }
    }

    private func duplicate(_ file: URL) {
        guard !busy else { return }
        busy = true
        Task {
            do {
                let selected = file
                _ = try await Task.detached(priority: .userInitiated) {
                    try NexaLocalFiles.duplicate(selected)
                }.value
                reload()
            } catch { notice = error.localizedDescription }
            busy = false
        }
    }
}

struct FileInspectorView: View {
    @EnvironmentObject private var language: NexaLanguage
    let file: URL
    @State private var preview = Data()
    @State private var showHex = true
    @State private var validation: String?
    @State private var readError: String?
    @State private var extracting = false
    @State private var archiveNotice: String?

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    NexaHeader(title: language.t("files.inspector"), subtitle: file.lastPathComponent)
                    NexaCard {
                        HStack {
                            Image(systemName: "doc.zipper").foregroundStyle(NexaPalette.blue)
                            Text(language.t("files.size")).foregroundStyle(NexaPalette.muted)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        }
                    }
                    Picker("", selection: $showHex) {
                        Text(language.t("files.hex")).tag(true)
                        Text(language.t("files.text")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    NexaCard {
                        if let readError {
                            Text(readError).foregroundStyle(.red)
                        } else if showHex {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(preview.map { String(format: "%02X", $0) }.joined(separator: " "))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(NexaPalette.mint)
                                    .textSelection(.enabled)
                                Text(language.t("files.truncated"))
                                    .font(.caption2).foregroundStyle(NexaPalette.muted)
                                Button {
                                    // Validate the bytes through WQFiles' vendored WQCore parser.
                                    let encoded = preview.map { String(format: "%02X", $0) }.joined(separator: " ")
                                    if let parsed = WQParseHexExactly(encoded, UInt(preview.count)) {
                                        validation = (parsed as Data) == preview
                                            ? language.t("files.hex.ok")
                                            : language.t("files.hex.fail")
                                    } else {
                                        validation = language.t("files.hex.fail")
                                    }
                                } label: {
                                    Label(language.t("files.hex.check"), systemImage: "checkmark.shield")
                                }
                                if let validation {
                                    Text(validation).font(.footnote).foregroundStyle(NexaPalette.muted)
                                }
                            }
                        } else {
                            Text(String(data: preview, encoding: .utf8) ?? language.t("files.no.preview"))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    if file.pathExtension.lowercased() == "plist" {
                        NavigationLink {
                            NexaPlistInspectorView(file: file)
                        } label: {
                            Label(language.code == "en" ? "Open plist editor" : "打开属性列表编辑器",
                                  systemImage: "slider.horizontal.3")
                        }
                        .buttonStyle(.bordered)
                    }
                    if file.pathExtension.lowercased() == "zip" {
                        Button { extractZip() } label: {
                            Label(
                                language.code == "en" ? "Extract ZIP into Nexa" : "解压 ZIP 到 Nexa",
                                systemImage: "archivebox.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(extracting)
                    }
                    ShareLink(item: file) {
                        Label(language.t("files.export"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
        }
        .navigationTitle(file.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: read)
        .alert(language.code == "en" ? "Archive result" : "压缩包操作", isPresented: Binding(
            get: { archiveNotice != nil },
            set: { if !$0 { archiveNotice = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { archiveNotice = nil }
        } message: {
            Text(archiveNotice ?? "")
        }
    }

    private func extractZip() {
        extracting = true
        Task {
            do {
                let source = file
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaZipManager.extractImportedArchive(source)
                }.value
                archiveNotice = language.code == "en"
                    ? "Extracted to \(result.file.lastPathComponent). Skipped entries: \(result.skipped)."
                    : "已解压到 \(result.file.lastPathComponent)，跳过条目：\(result.skipped)。"
            } catch {
                archiveNotice = error.localizedDescription
            }
            extracting = false
        }
    }

    private var size: Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func read() {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            preview = try handle.read(upToCount: 256) ?? Data()
        } catch { readError = error.localizedDescription }
    }
}
