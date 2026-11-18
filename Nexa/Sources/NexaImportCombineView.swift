import SwiftUI

/// A deliberately non-destructive file-level Merge/Replace on user-imported
/// snapshots. The result is a *new folder*, never a write to WeChat or another app.
struct NexaImportCombineView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var folders: [URL] = []
    @State private var source: URL?
    @State private var target: URL?
    @State private var mode: NexaImportCombine.Mode = .merge
    @State private var plan: NexaImportCombine.Plan?
    @State private var records: [NexaImportCombine.Receipt] = []
    @State private var busy = false
    @State private var confirming = false
    @State private var errorText: String?
    @State private var successText: String?

    private var en: Bool { language.code == "en" }

    private func display(_ url: URL) -> String {
        let root = AppPaths.importFolder.resolvingSymlinksInPath().standardizedFileURL
        let path = url.resolvingSymlinksInPath().standardizedFileURL
        let parts = path.pathComponents.dropFirst(root.pathComponents.count)
        return parts.joined(separator: "/")
    }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(
                        title: en ? "Merge / Replace snapshots" : "文件级合并与替换",
                        subtitle: en ? "For data already imported into Nexa" : "仅处理已导入 Nexa 的数据"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(
                                en ? "Originals are never changed" : "来源和目标原件绝不修改",
                                systemImage: "shield.checkered"
                            )
                            .foregroundStyle(NexaPalette.mint)
                            .font(.headline)
                            Text(en
                                ? "Creates a new SHA-256-verified result folder in Nexa's Imports. It does not write to WeChat, exchange containers, or merge individual chat database rows."
                                : "结果会作为经过 SHA-256 校验的新文件夹保存到 Nexa 导入区。不会写入微信、交换其他 App 容器，也不会逐条合并聊天数据库记录。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    if let risk = NexaSafetyCatalog.entry(for: "wcmigrate") {
                        NexaRiskNotice(risk: risk)
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker(en ? "Operation" : "操作方式", selection: $mode) {
                                Text(en ? "File merge" : "文件级合并")
                                    .tag(NexaImportCombine.Mode.merge)
                                Text(en ? "File replace" : "文件级替换")
                                    .tag(NexaImportCombine.Mode.replace)
                            }
                            .pickerStyle(.segmented)
                            Text(mode == .merge
                                 ? (en
                                    ? "Result = existing target files + source files. Same-name files use the source version."
                                    : "结果 = 目标已有文件 + 来源文件。同名文件在结果中采用来源版本。")
                                 : (en
                                    ? "Result = source files only. Extra target files are excluded from the new result, but the original target remains intact."
                                    : "结果只包含来源文件。目标多出的文件不放入新结果，但目标原件仍会保留。"))
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                            Divider().overlay(.white.opacity(0.08))
                            Picker(en ? "Source" : "来源文件夹", selection: $source) {
                                Text(en ? "Select a folder" : "选择文件夹")
                                    .tag(nil as URL?)
                                ForEach(folders, id: \.path) { url in
                                    Text(display(url)).tag(Optional(url))
                                }
                            }
                            .tint(NexaPalette.mint)
                            .pickerStyle(.menu)
                            Picker(en ? "Existing target" : "现有目标文件夹", selection: $target) {
                                Text(en ? "Select a folder" : "选择文件夹")
                                    .tag(nil as URL?)
                                ForEach(folders, id: \.path) { url in
                                    Text(display(url)).tag(Optional(url))
                                }
                            }
                            .tint(NexaPalette.mint)
                            .pickerStyle(.menu)
                            Text(en
                                ? "The selected folders cannot be the same or nested. Both must be user-imported Nexa folders."
                                : "两个文件夹不能相同或互为上下级，且必须已经导入 Nexa。")
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaActionButton(
                        title: en ? "Preview output files" : "预检结果文件",
                        symbol: "checkmark.shield"
                    ) { inspect() }
                    .disabled(source == nil || target == nil || busy)
                    if let plan {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(en ? "Proposed output" : "预计生成内容")
                                    .font(.headline)
                                HStack {
                                    Label("\(plan.expectedFiles.count) " + (en ? "files" : "个文件"),
                                          systemImage: "doc.on.doc")
                                    Spacer()
                                    Text(ByteCountFormatter.string(
                                        fromByteCount: plan.resultBytes, countStyle: .file
                                    ))
                                }
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                                Text(en
                                    ? "Same-name files: \(plan.overlaps). Extra target files retained in new result: \(plan.retainedTargetFiles)."
                                    : "同名文件：\(plan.overlaps) 个。新结果保留目标额外文件：\(plan.retainedTargetFiles) 个。")
                                    .font(.footnote)
                                    .foregroundStyle(NexaPalette.muted)
                                Button {
                                    confirming = true
                                } label: {
                                    Label(en ? "Create verified result" : "生成校验后的结果",
                                          systemImage: "arrow.down.doc")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(NexaPalette.violet)
                                .disabled(busy)
                            }
                        }
                    }
                    if busy {
                        ProgressView(en ? "Verifying imported files…" : "正在校验已导入文件…")
                            .tint(NexaPalette.mint)
                    }
                    if let successText {
                        NexaCard {
                            Text(successText)
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.mint)
                                .textSelection(.enabled)
                        }
                    }
                    if !records.isEmpty {
                        Text(en ? "Combined snapshots" : "已生成的结果记录")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(records) { item in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.resultName)
                                        .font(.subheadline.weight(.semibold))
                                        .textSelection(.enabled)
                                    HStack {
                                        NexaTag(text: item.mode == .merge
                                            ? (en ? "File merge" : "文件合并")
                                            : (en ? "File replace" : "文件替换"))
                                        NexaTag(text: item.state == .complete
                                            ? (en ? "Verified" : "校验完成")
                                            : (en ? "Needs review" : "需要检查"))
                                    }
                                    Text("\(item.fileCount) " + (en ? "files" : "个文件"))
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "File-level combine" : "文件级合并与替换")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .onChange(of: source) { _, _ in plan = nil }
        .onChange(of: target) { _, _ in plan = nil }
        .onChange(of: mode) { _, _ in plan = nil }
        .confirmationDialog(
            en ? "Create a new result folder?" : "确认生成新的结果文件夹？",
            isPresented: $confirming, titleVisibility: .visible
        ) {
            Button(en ? "Verify and create" : "校验并生成") { execute() }
            Button(language.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(en
                ? "No original folder is modified. A new SHA-256-verified directory is created only inside Nexa."
                : "不会修改来源或目标原文件夹；只在 Nexa 内生成一个新的 SHA-256 校验结果文件夹。")
        }
        .alert(en ? "File combination" : "文件合并与替换", isPresented: Binding(
            get: { errorText != nil },
            set: { if !$0 { errorText = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { errorText = nil }
        } message: { Text(errorText ?? "") }
    }

    private func reload() {
        do {
            try NexaImportCombine.recoverPending()
            folders = try NexaImportMigration.availableFolders().filter {
                $0.resolvingSymlinksInPath().standardizedFileURL !=
                    AppPaths.importFolder.resolvingSymlinksInPath().standardizedFileURL
            }
            records = try NexaImportCombine.receipts()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func inspect() {
        guard let source, let target, !busy else { return }
        plan = nil
        successText = nil
        busy = true
        let operation = mode
        Task {
            do {
                plan = try await Task.detached(priority: .userInitiated) {
                    try NexaImportCombine.preview(source: source, target: target, mode: operation)
                }.value
            } catch { errorText = error.localizedDescription }
            busy = false
        }
    }

    private func execute() {
        guard let proposal = plan, !busy else { return }
        busy = true
        Task {
            do {
                let receipt = try await Task.detached(priority: .userInitiated) {
                    try NexaImportCombine.execute(proposal)
                }.value
                plan = nil
                successText = en
                    ? "Created \(receipt.resultName) in Nexa Imports. Both originals are intact."
                    : "已在 Nexa 导入区生成 \(receipt.resultName)，来源和目标原件均保留。"
                reload()
            } catch { errorText = error.localizedDescription }
            busy = false
        }
    }
}
