import SwiftUI
import Foundation
import TransferCore

/// Local metadata preview using the pinned WCMigrate-derived iOS compatibility package.
/// No container-authorization bridge, migration execution or resume is exposed.
/// Inputs are already-imported, distinct top-level folders owned by Nexa.
enum NexaWCMigratePreview {
    enum Section: String, CaseIterable, Identifiable {
        case documents = "Documents"
        case library = "Library"
        var id: String { rawValue }
    }

    enum PreviewMode: String, CaseIterable, Identifiable {
        case replace, merge
        var id: String { rawValue }
        var upstream: TransferCore.TransferMode {
            self == .replace ? .replace : .merge
        }
    }

    private static func checkedFolder(_ selected: URL) throws -> URL {
        let folder = try NexaLocalFiles.validatedArchiveFolder(selected)
        let root = AppPaths.importFolder.resolvingSymlinksInPath().standardizedFileURL
        guard folder.deletingLastPathComponent().path == root.path else {
            throw NexaLocalFiles.FileError.outsideImports
        }
        // The pinned upstream Debug recovery fixture crashes on a 129-level
        // tree. Bound the app's local-only input until the core is validated.
        // This does not relax the upstream path or file-type checks.
        var enumerationError: Error?
        guard let entries = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey],
            errorHandler: { _, error in enumerationError = error; return false }
        ) else { throw TransferCore.TransferError.invalidPath }
        for case let entry as URL in entries {
            let flags = try entry.resourceValues(forKeys: [
                .isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey
            ])
            guard flags.isSymbolicLink != true,
                  flags.isDirectory == true || flags.isRegularFile == true else {
                throw TransferCore.TransferError.unsupportedFile
            }
            guard entries.level <= 32 else {
                throw TransferCore.PathDiagnostic("Local preview depth check", entry.path,
                    "Nexa local preview currently supports up to 32 directory levels. Choose a smaller imported snapshot.")
            }
        }
        if let enumerationError { throw enumerationError }
        return folder
    }

    static func availableFolders() throws -> [URL] {
        let fm = FileManager.default
        try fm.createDirectory(at: AppPaths.importFolder, withIntermediateDirectories: true)
        return try NexaLocalFiles.list(in: AppPaths.importFolder).filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]))
                .map { $0.isDirectory == true && $0.isSymbolicLink != true } ?? false
        }
    }

    static func preview(
        source: URL, target: URL, section: Section, mode: PreviewMode
    ) async throws -> TransferCore.MigrationSummary {
        let from = try checkedFolder(source)
        let to = try checkedFolder(target)
        guard from.path != to.path else { throw TransferCore.TransferError.invalidPath }

        // These are labels for local imported snapshots, NOT discovered or
        // impersonated application identities. The access callback is a no-op.
        let sourceInstance = TransferCore.AppInstance(
            displayName: from.lastPathComponent,
            bundleIdentifier: "local.nexa.imported.source",
            root: from, origin: "Nexa user import"
        )
        let targetInstance = TransferCore.AppInstance(
            displayName: to.lastPathComponent,
            bundleIdentifier: "local.nexa.imported.target",
            root: to, origin: "Nexa user import"
        )
        let service = TransferCore.DirectMigrationService(
            store: AppPaths.documents.appendingPathComponent("WCMigratePreviewOnly", isDirectory: true),
            prepareAccess: { _ in }
        )
        // The original preview checks relative paths, file inventories and
        // available space. It does not create a journal or apply any changes.
        return try await service.preview(
            source: sourceInstance, target: targetInstance,
            mappings: [TransferCore.DirectoryMapping(
                source: section.rawValue, target: section.rawValue
            )],
            mode: mode.upstream, keepSource: true, detailed: true
        )
    }
}

struct NexaWCMigratePreviewView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var folders: [URL] = []
    @State private var source: URL?
    @State private var target: URL?
    @State private var section = NexaWCMigratePreview.Section.documents
    @State private var mode = NexaWCMigratePreview.PreviewMode.replace
    @State private var summary: TransferCore.MigrationSummary?
    @State private var busy = false
    @State private var failure: String?
    @State private var didLoad = false

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(
                        title: en ? "Original migration preview" : "原版迁移预检",
                        subtitle: "WCMigrate · TransferCore"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(en ? "Preview only · imported snapshots" : "仅预检 · 已导入快照",
                                  systemImage: "lock.shield")
                                .font(.headline)
                                .foregroundStyle(NexaPalette.mint)
                            Text(en
                                ? "The pinned original DirectMigrationService checks the selected folder mapping, file counts, sizes and available space. No data is copied, deleted, exchanged or written back. This is not a live WeChat migration."
                                : "直接调用固定版本的原版 DirectMigrationService，检查目录映射、文件数量、大小和可用空间。不复制、删除、交换或写回数据；不是实时微信迁移。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker(en ? "Source snapshot" : "来源快照", selection: $source) {
                                Text(en ? "Select…" : "请选择…").tag(nil as URL?)
                                ForEach(folders, id: \.path) { item in
                                    Text(item.lastPathComponent).tag(Optional(item))
                                }
                            }
                            Picker(en ? "Target snapshot" : "目标快照", selection: $target) {
                                Text(en ? "Select…" : "请选择…").tag(nil as URL?)
                                ForEach(folders, id: \.path) { item in
                                    Text(item.lastPathComponent).tag(Optional(item))
                                }
                            }
                            Divider().overlay(.white.opacity(0.08))
                            Picker(en ? "Selected section" : "预检目录", selection: $section) {
                                ForEach(NexaWCMigratePreview.Section.allCases) { item in
                                    Text(item.rawValue).tag(item)
                                }
                            }
                            Picker(en ? "Preview mode" : "预检模式", selection: $mode) {
                                Text(en ? "Replace" : "替换").tag(NexaWCMigratePreview.PreviewMode.replace)
                                Text(en ? "Merge" : "合并").tag(NexaWCMigratePreview.PreviewMode.merge)
                            }
                            .pickerStyle(.segmented)
                            Text(mode == .replace
                                 ? (en ? "Replace semantics would remove target-only files within the selection. Nothing is applied here." : "替换语义会移除所选范围内的目标独有文件；此处不会执行。")
                                 : (en ? "Merge semantics preserve target-only files. This is file-level, not chat-record merging." : "合并语义保留目标独有文件；仅限文件级，不是聊天记录行级合并。"))
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                        }
                        .disabled(busy)
                    }
                    NexaActionButton(title: en ? "Run original preview" : "运行原版预检",
                                     symbol: "checkmark.shield") { runPreview() }
                    .disabled(busy || source == nil || target == nil || source == target)
                    if busy {
                        ProgressView(en ? "Checking selected snapshots…" : "正在检查所选快照…")
                            .tint(NexaPalette.mint)
                    }
                    if folders.count < 2 {
                        Text(en ? "Import two separate folders using Files first." : "请先在文件工作台导入两个独立文件夹。")
                            .font(.footnote)
                            .foregroundStyle(NexaPalette.muted)
                    }
                    if let failure {
                        NexaCard {
                            Text(failure).font(.footnote).foregroundStyle(.orange)
                                .textSelection(.enabled)
                        }
                    }
                    if let summary {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(en ? "Original preview completed" : "原版预检已完成",
                                      systemImage: "checkmark.circle")
                                    .foregroundStyle(NexaPalette.mint)
                                    .font(.headline)
                                metric(en ? "Source files" : "来源文件数", "\(summary.files)")
                                metric(en ? "Target files" : "目标文件数", "\(summary.targetFiles)")
                                metric(en ? "Source bytes" : "来源大小",
                                       ByteCountFormatter.string(fromByteCount: summary.bytes, countStyle: .file))
                                metric(en ? "Largest file" : "最大文件",
                                       ByteCountFormatter.string(fromByteCount: summary.largestFile, countStyle: .file))
                                metric(en ? "Mapping" : "目录映射",
                                       summary.mappings.map { $0.source + " → " + $0.target }.joined(separator: ", "))
                                if summary.inventoryComplete == false {
                                    Text(en ? "The original engine used a bounded inventory." : "原版引擎使用了有界目录清单。")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                }
                                Text(en ? "No files modified." : "未修改任何文件。")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(NexaPalette.mint)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "WCMigrate preview" : "WCMigrate 预检")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            #if DEBUG && targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("--nexa-wcmigrate-preview-smoke") {
                runSyntheticFixture()
                return
            }
            #endif
            do { folders = try NexaWCMigratePreview.availableFolders() }
            catch { failure = error.localizedDescription }
        }
        .onChange(of: source) { _, _ in if !busy { summary = nil } }
        .onChange(of: target) { _, _ in if !busy { summary = nil } }
        .onChange(of: section) { _, _ in if !busy { summary = nil } }
        .onChange(of: mode) { _, _ in if !busy { summary = nil } }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(NexaPalette.muted)
            Spacer(minLength: 10)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func runPreview() {
        guard let source, let target, source != target, !busy else { return }
        let selection = section
        let selectedMode = mode
        busy = true
        summary = nil
        failure = nil
        Task {
            defer { busy = false }
            do {
                summary = try await NexaWCMigratePreview.preview(
                    source: source, target: target, section: selection, mode: selectedMode
                )
            } catch {
                failure = error.localizedDescription
            }
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Disposable synthetic imports only. No real app data, access grant,
    /// or invocation of the original migration execution API.
    private func runSyntheticFixture() {
        busy = true
        Task {
            defer { busy = false }
            let fm = FileManager.default
            let marker = AppPaths.documents.appendingPathComponent(".nexa-wcmigrate-preview-result")
            let suffix = UUID().uuidString.prefix(8)
            let from = AppPaths.importFolder.appendingPathComponent("Sample source-" + suffix)
            let to = AppPaths.importFolder.appendingPathComponent("Sample target-" + suffix)
            let a = from.appendingPathComponent("Documents/alpha.txt")
            let b = from.appendingPathComponent("Documents/Nested/beta.txt")
            let c = to.appendingPathComponent("Documents/old.txt")
            let link = from.appendingPathComponent("Documents/unsafe-link")
            do {
                for url in [a, b, c] {
                    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                }
                try Data("alpha".utf8).write(to: a)
                try Data("beta".utf8).write(to: b)
                try Data("original target".utf8).write(to: c)
                folders = [from, to]
                source = from
                target = to
                for selectedMode in NexaWCMigratePreview.PreviewMode.allCases {
                    let result = try await NexaWCMigratePreview.preview(
                        source: from, target: to, section: .documents, mode: selectedMode
                    )
                    guard result.files == 2, result.targetFiles == 1,
                          result.bytes == 9, result.largestFile == 5,
                          result.preservesSource,
                          try Data(contentsOf: a) == Data("alpha".utf8),
                          try Data(contentsOf: b) == Data("beta".utf8),
                          try Data(contentsOf: c) == Data("original target".utf8),
                          !fm.fileExists(atPath: to.appendingPathComponent("Documents/alpha.txt").path)
                    else { throw TransferCore.TransferError.corruptBackup }
                    if selectedMode == .replace { summary = result }
                }
                // Same root, outside Imports and nested-link denial checks.
                var denied = 0
                do {
                    _ = try await NexaWCMigratePreview.preview(
                        source: from, target: from, section: .documents, mode: .merge
                    )
                } catch { denied += 1 }
                do {
                    _ = try await NexaWCMigratePreview.preview(
                        source: AppPaths.documents, target: to, section: .documents, mode: .merge
                    )
                } catch { denied += 1 }
                try fm.createSymbolicLink(at: link, withDestinationURL: c)
                do {
                    _ = try await NexaWCMigratePreview.preview(
                        source: from, target: to, section: .documents, mode: .merge
                    )
                } catch { denied += 1 }
                try fm.removeItem(at: link)
                guard denied == 3 else { throw TransferCore.TransferError.invalidPath }
                try "PASS: original WCMigrate preview and unchanged imports".write(
                    to: marker, atomically: true, encoding: .utf8
                )
            } catch {
                failure = error.localizedDescription
                try? ("FAIL: " + error.localizedDescription).write(
                    to: marker, atomically: true, encoding: .utf8
                )
            }
        }
    }
    #endif
}
