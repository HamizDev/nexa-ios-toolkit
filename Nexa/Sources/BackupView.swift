import SwiftUI

struct BackupView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var backups: [BackupRecord] = []
    @State private var busy = false
    @State private var message: String?

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
        Task {
            do {
                _ = try await Task.detached(priority: .userInitiated) { try BackupManager.createBackup() }.value
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
