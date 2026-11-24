import SwiftUI

struct NexaPlistHistoryView: View {
    @EnvironmentObject private var language: NexaLanguage
    let file: URL
    @State private var entries: [NexaPlistHistory.Record] = []
    @State private var selected: NexaPlistHistory.Record?
    @State private var notice: String?

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NexaHeader(
                        title: en ? "Version history" : "属性列表历史",
                        subtitle: file.lastPathComponent
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(en ? "Private, verified snapshots" : "私有、带哈希校验的历史副本",
                                  systemImage: "checkmark.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(en
                                ? "Every edit saves the previous imported plist. Restoring one version also backs up the current version. No system MobileGestalt values are changed."
                                : "每次编辑都会保留之前的已导入 plist。恢复历史版本前也会自动备份当前文件，不会修改系统 MobileGestalt。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    if entries.isEmpty {
                        NexaCard {
                            Text(en ? "No previous versions yet." : "暂无历史版本。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    ForEach(entries) { record in
                        NexaCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(record.savedAt, format: .dateTime.year().month().day().hour().minute().second())
                                    .font(.subheadline.weight(.semibold))
                                Text(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(NexaPalette.muted)
                                Text(record.sha256)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(NexaPalette.muted)
                                    .textSelection(.enabled)
                                HStack {
                                    Button {
                                        selected = record
                                    } label: {
                                        Label(en ? "Restore" : "恢复此版本", systemImage: "arrow.uturn.backward")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(NexaPalette.violet)
                                    if let url = try? NexaPlistHistory.snapshotURL(record, for: file) {
                                        ShareLink(item: url) {
                                            Label(en ? "Export" : "导出副本", systemImage: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Version history" : "历史版本")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog(
            en ? "Restore this imported plist version?" : "确定恢复此属性列表版本？",
            isPresented: Binding(
                get: { selected != nil },
                set: { if !$0 { selected = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(en ? "Restore and back up current" : "备份当前文件并恢复", role: .destructive) {
                if let selected {
                    do {
                        _ = try NexaPlistHistory.restore(selected, to: file)
                        reload()
                        notice = en ? "The imported plist was restored. Its previous version was preserved."
                                    : "已恢复导入文件，恢复前的版本也已保留。"
                    } catch {
                        notice = error.localizedDescription
                    }
                }
                selected = nil
            }
            Button(language.t("common.cancel"), role: .cancel) { selected = nil }
        } message: {
            Text(en ? "This does not change the device system cache."
                    : "只会修改 Nexa 已导入的副本，不会修改设备系统缓存。")
        }
        .alert(en ? "Plist history" : "属性列表历史", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private func reload() {
        do { entries = try NexaPlistHistory.versions(for: file) }
        catch { notice = error.localizedDescription }
    }
}
