import SwiftUI

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
                    if busy {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: progressFraction)
                                    .tint(NexaPalette.mint)
                                if let remaining = estimate.remaining {
                                    Text(language.code == "en"
                                        ? "Estimated remaining: \(Int(remaining)) seconds"
                                        : "预计剩余：\(OperationEstimate.timeText(remaining))")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                }
                                Text(language.code == "en" ? "Copy progress is measured by top-level items." : "进度按一级文件／目录统计，大目录可能耗时较长。")
                                    .font(.caption2).foregroundStyle(NexaPalette.muted)
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
                                        ShareLink(item: record.folder) {
                                            Label(language.t("backup.export"), systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .disabled(busy)
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
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
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
