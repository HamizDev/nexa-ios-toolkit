import SwiftUI

struct BackupView: View {
    @State private var backups: [BackupRecord] = []
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Text("把“我的文件”中已导入的数据复制到 App 内部备份目录，并生成 SHA-256 校验清单。不会修改原始文件、微信数据库或其他 App 容器。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    createBackup()
                } label: {
                    Label(busy ? "正在处理…" : "创建新备份", systemImage: "externaldrive.badge.plus")
                }
                .disabled(busy)
            }
            Section("本地备份") {
                if backups.isEmpty {
                    ContentUnavailableView("暂无备份", systemImage: "externaldrive", description: Text("先导入文件，再创建备份"))
                } else {
                    ForEach(backups) { backup in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(backup.name).font(.subheadline.weight(.medium)).textSelection(.enabled)
                            HStack {
                                Button("完整性校验") { verify(backup) }
                                    .buttonStyle(.bordered)
                                ShareLink(item: backup.folder) {
                                    Label("导出", systemImage: "square.and.arrow.up")
                                }.buttonStyle(.bordered)
                            }
                            .disabled(busy)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("备份与校验")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("刷新") { refresh() } } }
        .onAppear { refresh() }
        .alert("操作结果", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )) {
            Button("确定", role: .cancel) { message = nil }
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
                let _ = try await Task.detached(priority: .userInitiated) {
                    try BackupManager.createBackup()
                }.value
                message = "备份已创建，并记录了各文件的 SHA-256。"
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
                message = "校验通过：\(count) 个文件均与备份清单一致。"
            } catch { message = error.localizedDescription }
            busy = false
        }
    }
}
