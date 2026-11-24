import SwiftUI
import UniformTypeIdentifiers

// UI adapter only. The pinned original HermesCompanion manager owns
// backup file reception, SHA-256 manifests, import, export and Watch transfer.
struct WatchView: View {
    @EnvironmentObject private var language: NexaLanguage
    @EnvironmentObject private var companion: WatchConnectivityManager

    @State private var pingResult: String?
    @State private var message: String?
    @State private var showImport = false
    @State private var transferCandidate: WatchConnectivityManager.BackupRecord?
    @State private var showTransferDialog = false
    @State private var shareID: UUID?
    @State private var shareURL: URL?

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(
                        title: language.t("watch.title"),
                        subtitle: en ? "Hermes original backup companion" : "Hermes 原版备份伴侣"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(en ? "Watch connection" : "手表连接",
                                  systemImage: "applewatch")
                                .font(.headline)
                                .foregroundStyle(NexaPalette.violet)
                            info(en ? "Paired" : "已配对",
                                 companion.isPaired ? (en ? "Yes" : "是") : (en ? "No" : "否"))
                            info(en ? "NexaWatch installed" : "NexaWatch 已安装",
                                 companion.isWatchAppInstalled ? (en ? "Yes" : "是") : (en ? "No" : "否"))
                            info(en ? "Reachable" : "可连接",
                                 companion.isReachable ? (en ? "Yes" : "是") : (en ? "No" : "否"))
                            info(en ? "watchOS" : "手表系统", companion.watchOSVersion)
                            info(en ? "Build" : "构建号", companion.buildVersion)
                            HStack {
                                Button {
                                    companion.refreshConnectionStatus()
                                } label: {
                                    Label(language.t("common.refresh"), systemImage: "arrow.clockwise")
                                }
                                Button {
                                    companion.nexaPingWatch { value in pingResult = value }
                                } label: {
                                    Label(en ? "Test link" : "测试连接",
                                          systemImage: "arrow.left.arrow.right")
                                }
                                .disabled(!companion.isReachable)
                            }
                            .buttonStyle(.bordered)
                            if let pingResult {
                                Text(pingResult).font(.caption).foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(en ? "MobileGestalt backup history" : "MobileGestalt 备份历史",
                                  systemImage: "checkmark.shield")
                                .font(.headline).foregroundStyle(NexaPalette.mint)
                            Text(en
                                ? "The original Hermes iPhone companion receives Watch backup files, verifies SHA-256, and stores a local history. These backups are separate from Nexa Files."
                                : "直接复用 Hermes iPhone 原版备份接收、SHA-256 校验与历史记录；这些备份与 Nexa 本地文件备份相互独立。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Text(companion.backupStatus)
                                .font(.caption).foregroundStyle(NexaPalette.muted)
                            HStack {
                                Button {
                                    companion.loadBackupHistory()
                                } label: {
                                    Label(en ? "Refresh backups" : "刷新备份", systemImage: "arrow.clockwise")
                                }
                                Button {
                                    showImport = true
                                } label: {
                                    Label(en ? "Import MG plist" : "导入 MG plist",
                                          systemImage: "square.and.arrow.down")
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    if companion.backups.isEmpty {
                        NexaCard {
                            Label(en ? "No verified Watch backups yet." : "尚未收到经过校验的手表备份。",
                                  systemImage: "externaldrive")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    } else {
                        Text(en ? "Hermes backups" : "Hermes 原版备份")
                            .font(.title3.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(companion.backups) { record in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(record.formattedDate, systemImage: "archivebox.fill")
                                        .font(.subheadline.weight(.semibold))
                                    Text(record.fileName)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(NexaPalette.muted)
                                        .lineLimit(2)
                                    info(en ? "Size" : "大小", record.formattedSize)
                                    info(en ? "Source" : "来源", record.hashOrigin)
                                    Text("SHA-256  " + record.sha256)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(NexaPalette.muted)
                                        .textSelection(.enabled)
                                    Button {
                                        verify(record)
                                    } label: {
                                        Label(en ? "Verify hash" : "校验哈希",
                                              systemImage: "checkmark.seal")
                                    }
                                    .buttonStyle(.bordered)
                                    HStack {
                                        Button {
                                            prepareShare(record)
                                        } label: {
                                            Label(en ? "Prepare export" : "准备导出",
                                                  systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.bordered)
                                        Button {
                                            transferCandidate = record
                                            showTransferDialog = true
                                        } label: {
                                            Label(en ? "Send to Watch" : "发送到手表",
                                                  systemImage: "applewatch")
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!companion.isPaired || !companion.isWatchAppInstalled)
                                    }
                                    if shareID == record.id, let shareURL {
                                        ShareLink(item: shareURL) {
                                            Label(en ? "Share verified plist" : "分享已校验 plist",
                                                  systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                            }
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(en ? "Original-backup safety" : "原始备份安全",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.orange)
                            Text(en
                                ? "Restore the original MobileGestalt backup BEFORE uninstalling the Watch app. Keep the same Bundle ID and Apple ID. Sending a backup only queues a candidate for confirmation on the Watch; real-device rollback is unverified."
                                : "卸载手表 App 前务必恢复原始 MobileGestalt 备份，更新时保持相同 Bundle ID 和 Apple ID。向手表发送备份只会提交待确认候选；Nexa 尚未完成真机回滚测试。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        Link(destination: URL(string: "https://github.com/pookjw/HermesEnabler")!) {
                            Label(language.t("watch.source"), systemImage: "arrow.up.right.square")
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(language.t("watch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            companion.refreshConnectionStatus()
            companion.loadBackupHistory()
        }
        .fileImporter(
            isPresented: $showImport,
            allowedContentTypes: [.propertyList]
        ) { result in
            switch result {
            case .success(let file):
                do {
                    switch try companion.importBackup(from: file) {
                    case .imported(let record):
                        message = (en ? "Imported and verified: " : "已导入并校验：") + record.fileName
                    case .duplicate:
                        message = en ? "This backup is already saved." : "相同备份已经存在。"
                    }
                } catch {
                    message = error.localizedDescription
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .confirmationDialog(
            en ? "Queue backup for Watch?" : "将备份发送到手表？",
            isPresented: $showTransferDialog, titleVisibility: .visible
        ) {
            Button(en ? "Verify and queue" : "校验并提交") {
                if let transferCandidate { send(transferCandidate) }
                transferCandidate = nil
            }
            Button(language.t("common.cancel"), role: .cancel) {
                transferCandidate = nil
            }
        } message: {
            Text(en
                ? "Hermes verifies the saved SHA-256, then queues a restore candidate. Import it separately on the Watch. This phone action does not directly write system files."
                : "Hermes 原版引擎先验证 SHA-256，再向手表提交待恢复候选。需在手表另行确认导入；此操作不会直接写入系统文件。")
        }
        .alert(en ? "Hermes companion" : "Hermes 伴侣", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { message = nil }
        } message: { Text(message ?? "") }
    }

    private func info(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(NexaPalette.muted)
            Spacer(minLength: 8)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }

    private func verify(_ record: WatchConnectivityManager.BackupRecord) {
        switch companion.verifyBackup(record) {
        case .valid:
            message = en ? "SHA-256 verified." : "SHA-256 校验通过。"
        case .invalid:
            message = en ? "Backup content changed." : "备份内容已发生变化。"
        case .missing:
            message = en ? "Backup file missing." : "备份文件丢失。"
        case .error(let error):
            message = error
        }
    }

    private func prepareShare(_ record: WatchConnectivityManager.BackupRecord) {
        shareID = nil
        shareURL = nil
        guard case .valid = companion.verifyBackup(record),
              let file = companion.exportURL(for: record) else {
            message = en ? "Backup integrity verification failed." : "备份校验失败，不能导出。"
            return
        }
        shareID = record.id
        shareURL = file
    }

    private func send(_ record: WatchConnectivityManager.BackupRecord) {
        guard let file = companion.exportURL(for: record),
              companion.transferBackupToWatch(at: file) else {
            message = en
                ? "Could not queue transfer. Check the backup and Watch."
                : "无法提交传输，请检查备份及手表状态。"
            return
        }
        message = en
            ? "Backup transfer queued. Confirm import on your Watch."
            : "备份已排队发送，请在手表上确认导入。"
    }
}
