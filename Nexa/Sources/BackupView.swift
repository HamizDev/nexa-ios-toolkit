import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var backups: [BackupRecord] = []
    @State private var busy = false
    @State private var creating = false
    private enum PendingAction {
        case restore(BackupRecord)
        case delete(BackupRecord)
    }
    @State private var pendingAction: PendingAction?
    @State private var importSheet = false
    @State private var message: String?
    @State private var progressFraction: Double = 0
    @State private var estimate = OperationEstimate()
    @State private var verifiedIDs: Set<String> = []

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("backup.title"), subtitle: language.t("backup.subtitle"))
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(language.t("backup.info"), systemImage: "shield.lefthalf.filled")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Text(en ? "\(backups.count) local backups" : "\(backups.count) 个本地备份")
                                .font(.headline)
                            if let bytes = BackupPackageLibrary.knownLogicalBytes(backups) {
                                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                    .font(.title2.weight(.semibold))
                                Text(en ? "Known logical file size (not allocated disk space)." : "已统计文件的逻辑大小，并非实际磁盘占用。")
                                    .font(.caption).foregroundStyle(NexaPalette.muted)
                            }
                            let unknown = backups.filter { $0.logicalBytes == nil }.count
                            if unknown > 0 {
                                Text(en ? "\(unknown) backup sizes unavailable." : "\(unknown) 个备份大小无法统计。")
                                    .font(.caption).foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                    NexaActionButton(title: language.t(creating ? "backup.creating" : "backup.create"), symbol: "externaldrive.badge.plus") {
                        createBackup()
                    }
                    .disabled(busy)
                    Button { importSheet = true } label: {
                        Label(en ? "Import backup folder" : "导入备份目录", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)
                    Text(en ? "Choose a Nexa backup folder containing manifest.json and Payload. It will be copied and verified before being added." :
                         "选择包含 manifest.json 和 Payload 的 Nexa 备份目录。复制并校验成功后才会加入备份历史。")
                        .font(.caption).foregroundStyle(NexaPalette.muted)
                    if creating {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: progressFraction).tint(NexaPalette.mint)
                                if let remaining = estimate.remaining, progressFraction < 1 {
                                    Text(en ? "Estimated remaining: \(Int(remaining)) seconds" :
                                         "预计剩余：\(OperationEstimate.timeText(remaining))")
                                        .font(.caption).foregroundStyle(NexaPalette.muted)
                                }
                                Text(en ? "Copy progress is measured by top-level items. Verification may continue after copying." :
                                     "进度按一级文件／目录统计，复制完成后仍需校验。")
                                    .font(.caption2).foregroundStyle(NexaPalette.muted)
                            }
                        }
                    } else if busy {
                        ProgressView().tint(NexaPalette.mint)
                    }
                    Text(language.t("backup.list")).font(.title3.weight(.semibold))
                    if backups.isEmpty {
                        NexaCard {
                            VStack(spacing: 10) {
                                Image(systemName: "externaldrive").font(.system(size: 36)).foregroundStyle(NexaPalette.violet)
                                Text(language.t("backup.empty")).font(.subheadline).foregroundStyle(NexaPalette.muted)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    } else {
                        ForEach(backups) { record in
                            backupCard(record)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !busy else { return }
            busy = true
            await refresh()
            busy = false
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard !busy else { return }
                    busy = true
                    Task { await refresh(); busy = false }
                } label: { Label(language.t("common.refresh"), systemImage: "arrow.clockwise") }
                .disabled(busy)
            }
        }
        .fileImporter(isPresented: $importSheet, allowedContentTypes: [.folder], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let folder = urls.first { importBackup(folder) }
            case .failure(let error): message = error.localizedDescription
            }
        }
        .confirmationDialog(actionTitle, isPresented: Binding(
            get: { pendingAction != nil },
            set: { if !$0 { pendingAction = nil } }
        ), titleVisibility: .visible, presenting: pendingAction) { action in
            switch action {
            case .restore(let record):
                Button(language.t("backup.restore")) {
                    pendingAction = nil
                    restore(record)
                }
            case .delete(let record):
                Button(en ? "Permanently delete" : "永久删除", role: .destructive) {
                    pendingAction = nil
                    delete(record)
                }
            }
            Button(language.t("common.cancel"), role: .cancel) { pendingAction = nil }
        } message: { action in
            switch action {
            case .restore:
                Text(language.t("backup.restore.detail"))
            case .delete:
                Text(en ? "Only this local backup is removed. Imported files and external copies are kept." :
                     "仅永久删除此本地备份，不会删除已导入文件或外部副本。")
            }
        }
        .alert(language.t("backup.result"), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private var actionTitle: String {
        switch pendingAction {
        case .restore?: return language.t("backup.restore.confirm")
        case .delete?: return en ? "Delete this backup?" : "删除此备份？"
        case nil: return ""
        }
    }

    private func backupCard(_ record: BackupRecord) -> some View {
        NexaCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(record.name, systemImage: "externaldrive").font(.subheadline.weight(.medium)).lineLimit(2)
                if let manifest = record.manifest {
                    Text(manifest.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(NexaPalette.muted)
                    Text(en ? "Manifest v\(manifest.formatVersion) · \(manifest.files.count) listed files" :
                         "清单 v\(manifest.formatVersion) · 记录 \(manifest.files.count) 个文件")
                        .font(.caption).foregroundStyle(NexaPalette.muted)
                    Text(verifiedIDs.contains(record.id) ? (en ? "Verified this session" : "本次已校验") :
                         (en ? "Integrity not yet checked" : "尚未校验完整性"))
                        .font(.caption).foregroundStyle(verifiedIDs.contains(record.id) ? NexaPalette.mint : NexaPalette.muted)
                } else {
                    Text(en ? "Unreadable or invalid package" : "备份结构无效或无法读取")
                        .font(.caption).foregroundStyle(.orange)
                }
                if let bytes = record.logicalBytes {
                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        .font(.caption).foregroundStyle(NexaPalette.muted)
                }
                ViewThatFits(in: .horizontal) {
                    HStack { verifyAndShare(record) }
                    VStack(alignment: .leading) { verifyAndShare(record) }
                }
                ViewThatFits(in: .horizontal) {
                    HStack { restoreAndDelete(record) }
                    VStack(alignment: .leading) { restoreAndDelete(record) }
                }
            }
        }
    }

    @ViewBuilder private func verifyAndShare(_ record: BackupRecord) -> some View {
        Button { verify(record) } label: { Label(language.t("backup.verify"), systemImage: "checkmark.seal") }
            .buttonStyle(.bordered)
            .disabled(busy)
        ShareLink(item: record.folder) { Label(language.t("backup.export"), systemImage: "square.and.arrow.up") }
            .buttonStyle(.bordered)
            .disabled(busy || record.manifest == nil)
    }

    @ViewBuilder private func restoreAndDelete(_ record: BackupRecord) -> some View {
        Button { pendingAction = .restore(record) } label: { Label(language.t("backup.restore"), systemImage: "arrow.uturn.backward.circle") }
            .buttonStyle(.bordered)
            .disabled(busy || record.manifest == nil)
        Button(role: .destructive) { pendingAction = .delete(record) } label: {
            Label(en ? "Delete backup" : "删除备份", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .disabled(busy)
    }

    private func refresh() async {
        verifiedIDs.removeAll()
        do {
            backups = try await Task.detached(priority: .utility) {
                try BackupManager.listBackups()
            }.value
        } catch { message = errorText(error) }
    }

    private func createBackup() {
        guard !busy else { return }
        busy = true
        creating = true
        progressFraction = 0
        estimate.reset()
        Task {
            defer { creating = false; busy = false }
            do {
                let folder = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.createBackup(onProgress: { progress in
                        Task { @MainActor in
                            guard creating else { return }
                            progressFraction = max(progressFraction, progress.fraction ?? 0)
                            estimate.update(progress)
                        }
                    })
                }.value
                await refresh()
                verifiedIDs.insert(folder.path)
                message = language.t("backup.success")
            } catch { message = errorText(error) }
        }
    }

    private func importBackup(_ source: URL) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                let imported = try await Task.detached(priority: .userInitiated) {
                    let access = source.startAccessingSecurityScopedResource()
                    defer { if access { source.stopAccessingSecurityScopedResource() } }
                    var coordinationError: NSError?
                    var imported: Result<URL, Error>?
                    NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinationError) { url in
                        imported = Result { try BackupManager.importBackup(url) }
                    }
                    if let coordinationError { throw coordinationError }
                    guard let imported else { throw BackupPackageLibrary.Failure.invalidPackage }
                    return try imported.get()
                }.value
                await refresh()
                verifiedIDs.insert(imported.path)
                message = en ? "Backup copied and verified successfully." : "备份已复制并通过完整性校验。"
            } catch { message = errorText(error) }
        }
    }

    private func verify(_ backup: BackupRecord) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            verifiedIDs.remove(backup.id)
            do {
                let count = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.verify(backup.folder)
                }.value
                verifiedIDs.insert(backup.id)
                message = String(format: language.t("backup.ok"), count)
            } catch { message = errorText(error) }
        }
    }

    private func restore(_ backup: BackupRecord) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            verifiedIDs.remove(backup.id)
            do {
                let restored = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.restore(backup.folder)
                }.value
                verifiedIDs.insert(backup.id)
                message = language.t("backup.restore.success") + restored.lastPathComponent
            } catch { message = errorText(error) }
        }
    }

    private func delete(_ backup: BackupRecord) {
        guard !busy else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await Task.detached(priority: .userInitiated) {
                    try BackupManager.removeBackup(backup.folder)
                }.value
                await refresh()
                message = en ? "Local backup deleted." : "本地备份已删除。"
            } catch { message = errorText(error) }
        }
    }

    private func errorText(_ error: Error) -> String {
        if let error = error as? BackupManager.BackupError { return error.message(in: language.code) }
        if let error = error as? BackupPackageLibrary.Failure { return error.message(in: language.code) }
        return error.localizedDescription
    }
}
