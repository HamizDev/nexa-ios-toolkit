import SwiftUI

struct NexaFileNamePrompt: Identifiable {
    let id = UUID()
    let titleZh: String
    let titleEn: String
    let initialValue: String
    let target: URL?
}

struct NexaFileNameSheet: View {
    @EnvironmentObject private var language: NexaLanguage
    @Environment(\.dismiss) private var dismiss
    let request: NexaFileNamePrompt
    let onSave: (String) -> Void
    @State private var name: String

    init(request: NexaFileNamePrompt, onSave: @escaping (String) -> Void) {
        self.request = request
        self.onSave = onSave
        _name = State(initialValue: request.initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(language.code == "en" ? "Name" : "名称", text: $name)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                } footer: {
                    Text(language.code == "en"
                         ? "Only files in Nexa's imported folder are affected. Existing items are never overwritten."
                         : "仅操作 Nexa 的导入文件区；不会覆盖同名的现有文件。")
                }
            }
            .navigationTitle(language.code == "en" ? request.titleEn : request.titleZh)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language.code == "en" ? "Save" : "保存") {
                        onSave(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct NexaTrashView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var records: [NexaLocalFiles.TrashRecord] = []
    @State private var deleteCandidate: NexaLocalFiles.TrashRecord?
    @State private var notice: String?

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(
                        title: en ? "Recently deleted" : "最近删除",
                        subtitle: en ? "Recover files imported into Nexa" : "恢复从 Nexa 导入区删除的文件"
                    )
                    NexaCard {
                        Label(
                            en ? "Deleted files stay inside Nexa until permanently deleted or the app is uninstalled."
                               : "删除的文件会保留在 Nexa 的私有回收站，直至永久删除或卸载 App。",
                            systemImage: "shield.lefthalf.filled"
                        )
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                    }
                    if records.isEmpty {
                        NexaCard {
                            Text(en ? "Trash is empty." : "回收站为空。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                    } else {
                        ForEach(records) { item in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                        .textSelection(.enabled)
                                    Text(item.originalRelativePath)
                                        .font(.caption)
                                        .foregroundStyle(NexaPalette.muted)
                                        .textSelection(.enabled)
                                    Text(item.deletedAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(NexaPalette.muted)
                                    HStack(spacing: 12) {
                                        Button {
                                            restore(item)
                                        } label: {
                                            Label(en ? "Restore" : "恢复", systemImage: "arrow.uturn.backward")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(NexaPalette.violet)
                                        Button(role: .destructive) {
                                            deleteCandidate = item
                                        } label: {
                                            Label(en ? "Delete forever" : "永久删除", systemImage: "trash")
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
        .navigationTitle(en ? "Recently deleted" : "最近删除")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .refreshable { reload() }
        .confirmationDialog(
            en ? "Permanently delete this item?" : "确定永久删除这个文件？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(en ? "Delete permanently" : "永久删除", role: .destructive) {
                guard let item = deleteCandidate else { return }
                deleteCandidate = nil
                do {
                    try NexaLocalFiles.permanentlyDelete(item)
                    reload()
                } catch { notice = error.localizedDescription }
            }
            Button(language.t("common.cancel"), role: .cancel) { deleteCandidate = nil }
        } message: {
            Text(en
                 ? "This cannot be undone. Make sure you have exported any important files."
                 : "此操作不可撤销。请确认重要文件已经另行备份。")
        }
        .alert(en ? "Files" : "文件操作", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
    }

    private func reload() {
        do { records = try NexaLocalFiles.trashItems() }
        catch { notice = error.localizedDescription }
    }

    private func restore(_ record: NexaLocalFiles.TrashRecord) {
        do {
            let destination = try NexaLocalFiles.restore(record)
            reload()
            notice = en
                ? "Restored to \(destination.lastPathComponent)."
                : "已恢复至 \(destination.lastPathComponent)。"
        } catch { notice = error.localizedDescription }
    }
}
