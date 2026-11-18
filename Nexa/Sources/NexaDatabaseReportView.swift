import SwiftUI

struct NexaDatabaseReportView: View {
    @EnvironmentObject private var language: NexaLanguage
    let folder: URL
    @State private var reports: [DatabaseReport] = []
    @State private var processing = true
    @State private var failure: String?

    var body: some View {
        let english = language.code == "en"
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NexaHeader(
                        title: english ? "SQLite diagnostics" : "SQLite 数据库诊断",
                        subtitle: folder.lastPathComponent
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(english ? "Verified backup · Read only" : "已校验备份 · 只读",
                                  systemImage: "checkmark.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(english
                                ? "Runs the upstream WCMigrate quick_check on disposable copies of databases from this Nexa backup. This does not recover chats or verify decryption keys."
                                : "对 Nexa 备份中的数据库临时副本运行 WCMigrate 的 quick_check。不能据此确认聊天记录可恢复或密钥兼容。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    if processing {
                        ProgressView().tint(NexaPalette.mint)
                    } else if let failure {
                        NexaCard {
                            Text(failure).font(.footnote).foregroundStyle(.red)
                        }
                    } else if reports.isEmpty {
                        NexaCard {
                            Text(english ? "No .db or .sqlite files found in this backup." : "此备份中没有发现 .db 或 .sqlite 数据库。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    } else {
                        ForEach(reports) { report in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(report.path)
                                        .font(.subheadline.weight(.semibold))
                                        .textSelection(.enabled)
                                    Text(english ? "Integrity result: \(report.result)" : "完整性检查：\(report.result)")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                    HStack {
                                        NexaTag(text: "\(report.tables.count) tables", color: NexaPalette.blue)
                                        NexaTag(text: "\(report.indexCount) indexes", color: NexaPalette.mint)
                                    }
                                    Text("WAL: \(report.hasWAL ? "yes" : "no")  ·  SHM: \(report.hasSHM ? "yes" : "no")")
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                    ForEach(report.tables.prefix(15), id: \.self) { table in
                                        Text(table)
                                            .font(.system(.caption2, design: .monospaced))
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
        .navigationTitle(english ? "Database check" : "数据库检查")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            processing = true
            do {
                let input = folder
                reports = try await Task.detached(priority: .userInitiated) {
                    try DatabaseInspector.inspect(backupDirectory: input)
                }.value
            } catch { failure = error.localizedDescription }
            processing = false
        }
    }
}
