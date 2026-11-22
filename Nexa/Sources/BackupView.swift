import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var backups: [BackupRecord] = []
    @State private var busy = false
    @State private var message: String?
    @State private var progressFraction: Double = 0
    @State private var estimate = OperationEstimate()
    @State private var restoreCandidate: BackupRecord?
    @State private var showRestoreDialog = false
    @State private var previousImports: URL?
    @State private var portableArchives: [String: URL] = [:]
    @State private var showPortableImport = false
    @State private var portableImportBusy = false
    @State private var recoveryCopies: [NexaBackupRestore.RecoveryCopy] = []
    @State private var recoveryExports: [String: URL] = [:]

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("backup.title"), subtitle: language.t("backup.subtitle"))
                    NexaCard {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundStyle(NexaPalette.mint)
                            Text(language.t("backup.info"))
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaActionButton(title: language.t(busy ? "backup.creating" : "backup.create"), symbol: "externaldrive.badge.plus") {
                        createBackup()
                    }
                    .disabled(busy)
                    Button {
                        showPortableImport = true
                    } label: {
                        Label(
                            language.code == "en" ? "Import backup ZIP" : "导入备份 ZIP",
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    if busy {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 8) {
                                if portableImportBusy {
                                    ProgressView(language.code == "en"
                                        ? "Validating imported backup ZIP…" : "正在校验并导入备份 ZIP…")
                                        .tint(NexaPalette.mint)
                                } else {
                                    ProgressView(value: progressFraction)
                                        .tint(NexaPalette.mint)
                                }
                                if !portableImportBusy, let remaining = estimate.remaining {
                                    Text(language.code == "en"
                                        ? "Estimated remaining: \(Int(remaining)) seconds"
                                        : "预计剩余：\(OperationEstimate.timeText(remaining))")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                }
                                if !portableImportBusy {
                                    Text(language.code == "en"
                                        ? "Copy progress is measured by top-level items."
                                        : "进度按一级文件／目录统计，大目录可能耗时较长。")
                                        .font(.caption2).foregroundStyle(NexaPalette.muted)
                                }
                            }
                        }
                    }
                    if let previousImports {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(language.code == "en" ? "Previous files retained" : "已保留恢复前的文件")
                                    .font(.subheadline.weight(.semibold))
                                ShareLink(item: previousImports) {
                                    Label(language.code == "en" ? "Export previous files" : "导出恢复前的数据", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                    }
                    NavigationLink {
                        NexaMigrationView()
                    } label: {
                        NexaCard {
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.left.arrow.right.square")
                                    .font(.title2)
                                    .foregroundStyle(NexaPalette.violet)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(language.code == "en" ? "Local data migration" : "本地数据迁移")
                                        .font(.headline)
                                    Text(language.code == "en"
                                        ? "SHA-256-verified copy of user-imported data"
                                        : "对已导入数据执行 SHA-256 校验复制")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Text(language.t("backup.list")).font(.title3.weight(.semibold))
                    if backups.isEmpty {
                        NexaCard {
                            VStack(spacing: 10) {
                                Image(systemName: "externaldrive")
                                    .font(.system(size: 36))
                                    .foregroundStyle(NexaPalette.violet)
                                Text(language.t("backup.empty"))
                                    .font(.subheadline)
                                    .foregroundStyle(NexaPalette.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else {
                        ForEach(backups) { record in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 13) {
                                    Label(record.name, systemImage: "checkmark.shield")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(2)
                                    HStack {
                                        Button { verify(record) } label: {
                                            Label(language.t("backup.verify"), systemImage: "checkmark.seal")
                                        }
                                        .buttonStyle(.bordered)
                                        Button { preparePortableZIP(record) } label: {
                                            Label(
                                                language.code == "en" ? "Prepare ZIP" : "生成 ZIP",
                                                systemImage: "archivebox"
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .disabled(busy)
                                    if let archive = portableArchives[record.id] {
                                        ShareLink(item: archive) {
                                            Label(
                                                language.code == "en" ? "Share verified backup ZIP" : "分享已校验的备份 ZIP",
                                                systemImage: "square.and.arrow.up"
                                            )
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(busy)
                                    }
                                    NavigationLink {
                                        NexaDatabaseReportView(folder: record.folder)
                                    } label: {
                                        Label(
                                            language.code == "en" ? "SQLite integrity report" : "SQLite 完整性检查",
                                            systemImage: "externaldrive.badge.checkmark"
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(busy)
                                    Button(role: .destructive) {
                                        restoreCandidate = record
                                        showRestoreDialog = true
                                    } label: {
                                        Label(language.code == "en" ? "Restore to Nexa Files" : "恢复到 Nexa 文件区", systemImage: "arrow.uturn.backward")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(busy)
                                }
                            }
                        }
                    }
                    if !recoveryCopies.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language.code == "en" ? "Retained recovery copies" : "保留的恢复副本")
                                .font(.title3.weight(.semibold))
                            Text(language.code == "en"
                                ? "Raw previous or rejected files are retained after restart. These are not SHA-256-verified backups; inspect before restoring any contents."
                                : "恢复前数据和失败回滚数据在重启后仍保留。这些不是经 SHA-256 清单验证的正式备份，请先检查内容再自行使用。")
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                            ForEach(recoveryCopies) { copy in
                                NexaCard {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Label(
                                            copy.kind == .previousImports
                                                ? (language.code == "en" ? "Before restore" : "恢复前的文件")
                                                : (language.code == "en" ? "Rejected after recovery" : "异常回滚保留的文件"),
                                            systemImage: copy.kind == .previousImports
                                                ? "arrow.uturn.backward.circle" : "exclamationmark.shield"
                                        )
                                        .font(.subheadline.weight(.semibold))
                                        Text(copy.folder.lastPathComponent)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(NexaPalette.muted)
                                            .lineLimit(2)
                                        Button { prepareRecoveryZIP(copy) } label: {
                                            Label(
                                                language.code == "en" ? "Package recovery ZIP" : "打包恢复副本 ZIP",
                                                systemImage: "archivebox"
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(busy)
                                        if let zip = recoveryExports[copy.id] {
                                            ShareLink(item: zip) {
                                                Label(
                                                    language.code == "en" ? "Share recovery ZIP" : "分享恢复副本 ZIP",
                                                    systemImage: "square.and.arrow.up"
                                                )
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(busy)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refresh()
            Task.detached(priority: .utility) {
                _ = try? NexaZipManager.discardInterruptedPortableImports()
            }
        }
        .fileImporter(
            isPresented: $showPortableImport,
            allowedContentTypes: [.zip]
        ) { result in
            switch result {
            case .success(let url):
                importPortableZIP(url)
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .confirmationDialog(
            language.code == "en" ? "Replace imported files?" : "确定替换现有导入文件？",
            isPresented: $showRestoreDialog,
            titleVisibility: .visible
        ) {
            Button(language.code == "en" ? "Verify and restore" : "校验并恢复", role: .destructive) {
                if let restoreCandidate { restore(restoreCandidate) }
            }
            Button(language.t("common.cancel"), role: .cancel) {
                restoreCandidate = nil
            }
        } message: {
            Text(language.code == "en"
                ? "The backup will be SHA-256 verified twice. Existing imported files will be retained in a private recovery snapshot. Other apps are never modified."
                : "将执行两次 SHA-256 校验，现有导入文件会保留为独立恢复副本。不会修改其他 App 的数据。")
        }
        .alert(language.code == "en" ? "Backup result" : "备份操作结果", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func refresh() {
        do {
            try NexaBackupRestore.recoverIfNeeded()
            backups = try BackupManager.listBackups()
            recoveryCopies = try NexaBackupRestore.listRecoveryCopies()
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore(_ record: BackupRecord) {
        busy = true
        restoreCandidate = nil
        Task {
            do {
                let selected = record.folder
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaBackupRestore.restore(from: selected)
                }.value
                previousImports = result.priorImports
                message = language.code == "en"
                    ? "Restored \(result.restoredFiles) verified files. Your previous imports were preserved."
                    : "已恢复 \(result.restoredFiles) 个校验通过的文件，原导入数据已保留。"
                refresh()
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }

    private func createBackup() {
        busy = true
        progressFraction = 0
        estimate.reset()
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.createBackup(onProgress: { progress in
                        Task { @MainActor in
                            progressFraction = progress.fraction ?? 0
                            estimate.update(progress)
                        }
                    })
                }.value
                message = language.t("backup.success")
                refresh()
            } catch { message = error.localizedDescription }
            busy = false
        }
    }

    private func importPortableZIP(_ file: URL) {
        guard !busy else { return }
        busy = true
        portableImportBusy = true
        Task {
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    let access = file.startAccessingSecurityScopedResource()
                    defer { if access { file.stopAccessingSecurityScopedResource() } }
                    return try NexaZipManager.importPortableBackup(file)
                }.value
                message = language.code == "en"
                    ? "Verified backup \(imported.lastPathComponent) is now in your backup list. Current imported files were not changed."
                    : "备份 \(imported.lastPathComponent) 已校验并加入列表；当前导入文件未被修改。"
                refresh()
            } catch {
                message = error.localizedDescription
            }
            portableImportBusy = false
            busy = false
        }
    }

    private func preparePortableZIP(_ backup: BackupRecord) {
        guard !busy else { return }
        busy = true
        portableArchives[backup.id] = nil
        Task {
            do {
                let selected = backup.folder
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaZipManager.createVerifiedBackupArchive(selected)
                }.value
                portableArchives[backup.id] = result.file
                message = language.code == "en"
                    ? "Verified ZIP ready. Share the ZIP to keep a portable copy of manifest.json and Payload."
                    : "校验后的备份 ZIP 已生成，可以分享保存，内含 manifest.json 和 Payload。"
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }

    private func prepareRecoveryZIP(_ copy: NexaBackupRestore.RecoveryCopy) {
        guard !busy else { return }
        busy = true
        recoveryExports[copy.id] = nil
        Task {
            do {
                let selected = copy.folder
                let result = try await Task.detached(priority: .userInitiated) {
                    try NexaZipManager.createRecoveryCopyArchive(selected)
                }.value
                recoveryExports[copy.id] = result.file
                message = language.code == "en"
                    ? "Recovery ZIP is ready. These raw retained files have no verified backup manifest."
                    : "恢复副本 ZIP 已生成。原始保留数据不包含经过校验的备份清单。"
            } catch {
                message = error.localizedDescription
            }
            busy = false
        }
    }

    private func verify(_ backup: BackupRecord) {
        busy = true
        Task {
            do {
                let count = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.verify(backup.folder)
                }.value
                message = String(format: language.t("backup.ok"), count)
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}
