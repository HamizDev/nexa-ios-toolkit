import SwiftUI

/// User-selected staging of imported app-data snapshots.
/// This is not a live WeChat container migration or chat merge tool.
struct NexaMigrationView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var folders: [URL] = []
    @State private var source: URL?
    @State private var destination: URL?
    @State private var plan: NexaImportMigration.Plan?
    @State private var history: [NexaImportMigration.Receipt] = []
    @State private var busy = false
    @State private var confirm = false
    @State private var error: String?
    @State private var message: String?

    private var en: Bool { language.code == "en" }
    private var root: URL { AppPaths.importFolder.resolvingSymlinksInPath().standardizedFileURL }
    private func title(_ url: URL) -> String {
        let parts = url.resolvingSymlinksInPath().standardizedFileURL.pathComponents
        let relative = parts.dropFirst(root.pathComponents.count).joined(separator: "/")
        return relative.isEmpty ? (en ? "Imported files" : "导入文件根目录") : relative
    }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(title: en ? "Local data migration" : "本地数据迁移",
                               subtitle: en ? "WCMigrate-style verified staging" : "基于 WCMigrate 思路的校验暂存")
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(en ? "Imported data only" : "仅限用户导入的数据",
                                  systemImage: "lock.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(en ?
                                 "Copy a user-imported app-data snapshot into another Nexa folder. The original data stays unchanged, and every copied file is SHA-256 verified. This does not transfer directly into WeChat or another app." :
                                 "将用户导入的应用数据快照复制到另一个 Nexa 文件夹。来源保持不变，逐文件执行 SHA-256 校验。不会直接写入微信或其他 App。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(en ? "Source folder" : "来源文件夹").font(.headline)
                                Spacer()
                                Picker(en ? "Source" : "来源", selection: $source) {
                                    Text(en ? "Select…" : "请选择…").tag(nil as URL?)
                                    ForEach(folders.filter { $0 != root }, id: \.path) { url in
                                        Text(title(url)).tag(Optional(url))
                                    }
                                }
                                .tint(NexaPalette.mint)
                            }
                            Divider().overlay(.white.opacity(0.08))
                            HStack {
                                Text(en ? "Destination" : "目标文件夹").font(.headline)
                                Spacer()
                                Picker(en ? "Destination" : "目标", selection: $destination) {
                                    Text(en ? "Select…" : "请选择…").tag(nil as URL?)
                                    ForEach(folders, id: \.path) { url in
                                        Text(title(url)).tag(Optional(url))
                                    }
                                }
                                .tint(NexaPalette.mint)
                            }
                        }
                    }
                    NexaActionButton(
                        title: en ? "Preview migration" : "预检迁移内容",
                        symbol: "checkmark.shield"
                    ) { preview() }
                    .disabled(busy || source == nil || destination == nil)
                    if let plan {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(en ? "Copy plan" : "迁移预览").font(.headline)
                                HStack {
                                    Label("\(plan.files.count)", systemImage: "doc.on.doc")
                                    Spacer()
                                    Label(ByteCountFormatter.string(fromByteCount: plan.totalBytes, countStyle: .file),
                                          systemImage: "internaldrive")
                                }
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                                Text(en
                                     ? "A new uniquely named folder will be created. Nothing in the destination is overwritten."
                                     : "将新建独立目标文件夹，不覆盖已有数据。")
                                    .font(.caption)
                                    .foregroundStyle(NexaPalette.muted)
                                Button { confirm = true } label: {
                                    Label(en ? "Verify and copy" : "校验并迁移副本", systemImage: "arrow.right.square")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(NexaPalette.violet)
                                .disabled(busy)
                            }
                        }
                    }
                    if busy { ProgressView(en ? "Checking files…" : "正在校验文件…").tint(NexaPalette.mint) }
                    if let message {
                        NexaCard { Text(message).font(.footnote).foregroundStyle(NexaPalette.mint) }
                    }
                    if !history.isEmpty {
                        Text(en ? "Migration history" : "迁移记录").font(.title3.weight(.semibold))
                        ForEach(history) { entry in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.source + " → " + entry.destination + "/" + entry.finalFolderName)
                                        .font(.subheadline.weight(.medium))
                                        .textSelection(.enabled)
                                    HStack {
                                        NexaTag(text: en ? entry.state.rawValue : (entry.state == .complete ? "已校验" : "未完成"))
                                        Text("\(entry.fileCount) " + (en ? "files" : "个文件"))
                                            .font(.caption)
                                            .foregroundStyle(NexaPalette.muted)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Migration" : "数据迁移")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog(
            en ? "Copy this imported data?" : "确认迁移已导入数据？",
            isPresented: $confirm, titleVisibility: .visible
        ) {
            Button(en ? "Start verified copy" : "开始校验复制") { execute() }
            Button(language.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(en
                 ? "The source will be preserved. This only copies within Nexa, and is not a WeChat restore."
                 : "保留来源文件，只在 Nexa 内部复制。这不是微信数据恢复。")
        }
        .alert(en ? "Migration error" : "迁移失败", isPresented: Binding(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func reload() {
        do {
            try NexaImportMigration.recoverIfNeeded()
            folders = try NexaImportMigration.availableFolders()
            history = try NexaImportMigration.receipts()
        } catch { self.error = error.localizedDescription }
    }

    private func preview() {
        guard let source, let destination else { return }
        plan = nil
        busy = true
        Task {
            do {
                plan = try await Task.detached(priority: .userInitiated) {
                    try NexaImportMigration.preview(source: source, destination: destination)
                }.value
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }

    private func execute() {
        guard let planned = plan else { return }
        busy = true
        Task {
            do {
                let receipt = try await Task.detached(priority: .userInitiated) {
                    try NexaImportMigration.execute(planned)
                }.value
                plan = nil
                message = en
                    ? "Verified \(receipt.fileCount) files. Source retained."
                    : "已校验迁移 \(receipt.fileCount) 个文件，来源保持不变。"
                reload()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
