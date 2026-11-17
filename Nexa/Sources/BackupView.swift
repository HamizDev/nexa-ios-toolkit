import SwiftUI

struct BackupView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var backups: [BackupRecord] = []
    @State private var busy = false
    @State private var message: String?
    @State private var progressFraction: Double = 0
    @State private var estimate = OperationEstimate()

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
        .alert(language.t("backup.error"), isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func refresh() {
        do { backups = try BackupManager.listBackups() }
        catch { message = error.localizedDescription }
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
