import Foundation
import SwiftUI
import Combine

// Offline editor for user-imported copies only. Never accepts a privileged system path.
struct NexaPlistEntry: Identifiable {
    let key: String
    let kind: PlistValueKind
    let valueText: String
    var id: String { key }
}

@MainActor
final class NexaPlistEditor: ObservableObject {
    @Published private(set) var entries: [NexaPlistEntry] = []
    @Published var search = ""
    @Published var statusMessage: String?
    @Published private(set) var editingCacheExtra = false
    @Published private(set) var history: [NexaPlistHistory.Record] = []
    @Published private(set) var historyError: String?
    @Published private(set) var canEdit = false

    let file: URL
    private var document: [String: Any] = [:]
    private var loadedBytes: Data?
    private var sourceFormat: PropertyListSerialization.PropertyListFormat = .xml
    private let historyStore = NexaPlistHistory(
        importRoot: AppPaths.importFolder,
        historyRoot: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nexa/PlistHistory", isDirectory: true)
    )

    init(file: URL) {
        self.file = file
    }

    var filtered: [NexaPlistEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.key.localizedCaseInsensitiveContains(search) ||
            $0.valueText.localizedCaseInsensitiveContains(search)
        }
    }

    func reload(language: String = "zh") {
        statusMessage = nil
        entries = []
        document = [:]
        loadedBytes = nil
        canEdit = false
        history = []
        historyError = nil
        do {
            let raw = try historyStore.read(file)
            var format = PropertyListSerialization.PropertyListFormat.xml
            guard let root = try PropertyListSerialization.propertyList(from: raw, options: [], format: &format) as? [String: Any] else {
                throw NexaPlistHistory.Failure.invalidPlist
            }
            sourceFormat = format
            document = root
            loadedBytes = raw
            canEdit = true
            editingCacheExtra = root["CacheExtra"] is [String: Any]
            let selected = (root["CacheExtra"] as? [String: Any]) ?? root
            entries = selected.keys.sorted().compactMap { key in
                guard let value = selected[key] else { return nil }
                let kind = PlistValueKind.detect(value)
                return NexaPlistEntry(key: key, kind: kind, valueText: kind.text(for: value))
            }
            do { history = try historyStore.records(for: file) }
            catch { historyError = errorText(error, language: language) }
        } catch {
            statusMessage = errorText(error, language: language)
        }
    }

    func save(entry: NexaPlistEntry, text: String, language: String) -> Bool {
        do {
            guard let expected = loadedBytes else { throw NexaPlistHistory.Failure.stale }
            guard text != entry.valueText else { throw NexaPlistHistory.Failure.unchanged }
            // Keep the original GestaltX value parser. Only the imported copy may be written.
            let parsed = try entry.kind.parse(text)
            var replacement = document
            if editingCacheExtra {
                guard var cache = replacement["CacheExtra"] as? [String: Any], cache[entry.key] != nil else {
                    throw NexaPlistHistory.Failure.stale
                }
                cache[entry.key] = parsed
                replacement["CacheExtra"] = cache
            } else {
                guard replacement[entry.key] != nil else { throw NexaPlistHistory.Failure.stale }
                replacement[entry.key] = parsed
            }
            // Preserve XML/binary format. Legacy OpenStep documents are serialized to XML.
            let updated = try PropertyListSerialization.data(
                fromPropertyList: replacement, format: sourceFormat == .binary ? .binary : .xml, options: 0
            )
            try historyStore.replace(file, expected: expected, with: updated)
            reload(language: language)
            return true
        } catch {
            statusMessage = errorText(error, language: language)
            return false
        }
    }

    func restore(_ record: NexaPlistHistory.Record, language: String) {
        do {
            guard let expected = loadedBytes else { throw NexaPlistHistory.Failure.stale }
            try historyStore.restore(record.id, to: file, expected: expected)
            reload(language: language)
            if canEdit {
                statusMessage = language == "en" ? "Version restored. The preceding version is retained in history." : "已恢复历史版本，恢复前的版本仍保留在历史记录中。"
            }
        } catch { statusMessage = errorText(error, language: language) }
    }

    private func errorText(_ error: Error, language: String) -> String {
        (error as? NexaPlistHistory.Failure)?.message(in: language) ?? error.localizedDescription
    }
}

struct NexaPlistInspectorView: View {
    @EnvironmentObject private var language: NexaLanguage
    @StateObject private var editor: NexaPlistEditor
    @State private var active: NexaPlistEntry?
    @State private var selectedHistory: NexaPlistHistory.Record?
    @State private var showHistory = false

    init(file: URL) {
        _editor = StateObject(wrappedValue: NexaPlistEditor(file: file))
    }

    var body: some View {
        let en = language.code == "en"
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    NexaHeader(
                        title: en ? "Property List" : "属性列表",
                        subtitle: editor.file.lastPathComponent
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(en ? "Offline editor · Imported copy" : "离线编辑 · 已导入副本",
                                  systemImage: "lock.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(en ?
                                 "Values use the GestaltX parser. Changes affect only the copy in Nexa, not system MobileGestalt." :
                                 "值类型解析来自 GestaltX。修改仅作用于 Nexa 内的副本，不会修改系统 MobileGestalt。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        DisclosureGroup(isExpanded: $showHistory) {
                            if let error = editor.historyError {
                                Text(error).font(.caption).foregroundStyle(.red)
                            } else if editor.history.isEmpty {
                                Text(en ? "No versions saved yet." : "尚无修改历史。")
                                    .font(.caption).foregroundStyle(NexaPalette.muted)
                            } else {
                                ForEach(editor.history) { record in
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(record.createdAt.formatted(date: .abbreviated, time: .standard))
                                            .font(.subheadline.weight(.semibold))
                                        Text(record.reason == .edit ? (en ? "Before edit" : "编辑前") : (en ? "Before restore" : "恢复前"))
                                            .font(.caption).foregroundStyle(NexaPalette.muted)
                                        Text(ByteCountFormatter.string(fromByteCount: Int64(record.byteCount), countStyle: .file))
                                            .font(.caption).foregroundStyle(NexaPalette.muted)
                                        Button {
                                            selectedHistory = record
                                        } label: {
                                            Label(en ? "Restore version" : "恢复此版本", systemImage: "arrow.uturn.backward.circle")
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(!editor.canEdit)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 7)
                                }
                            }
                        } label: {
                            Label(en ? "Version history (\(editor.history.count))" : "版本历史（\(editor.history.count)）",
                                  systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                        }
                    }
                    TextField(en ? "Search keys" : "搜索键名", text: $editor.search)
                        .textFieldStyle(.roundedBorder)
                    ForEach(editor.filtered) { entry in
                        Button { active = entry } label: {
                            NexaCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(entry.key)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(2)
                                        Spacer()
                                        NexaTag(text: entry.kind.rawValue)
                                    }
                                    Text(entry.valueText)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(NexaPalette.muted)
                                        .lineLimit(3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Plist" : "属性列表")
        .onAppear { editor.reload(language: language.code) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor.reload(language: language.code)
                } label: {
                    Label(language.t("common.refresh"), systemImage: "arrow.clockwise")
                }
            }
        }
        .confirmationDialog(en ? "Restore this version?" : "恢复此历史版本？", isPresented: Binding(
            get: { selectedHistory != nil },
            set: { if !$0 { selectedHistory = nil } }
        ), titleVisibility: .visible, presenting: selectedHistory) { record in
            Button(en ? "Restore imported copy" : "恢复导入副本", role: .destructive) {
                selectedHistory = nil
                editor.restore(record, language: language.code)
            }
            Button(language.t("common.cancel"), role: .cancel) { selectedHistory = nil }
        } message: { _ in
            Text(en ? "The current imported copy will be replaced. Its previous bytes will be kept in version history. No system file is changed." :
                 "将替换当前导入副本，但会保留恢复前的原始字节。不会修改系统文件。")
        }
        .sheet(item: $active) { entry in
            NexaPlistEditSheet(editor: editor, entry: entry)
                .environmentObject(language)
        }
        .alert(en ? "Editor status" : "编辑状态", isPresented: Binding(
            get: { editor.statusMessage != nil },
            set: { if !$0 { editor.statusMessage = nil } }
        )) {
            Button(en ? "OK" : "确定", role: .cancel) { editor.statusMessage = nil }
        } message: {
            Text(editor.statusMessage ?? "")
        }
    }
}

struct NexaPlistEditSheet: View {
    @EnvironmentObject private var language: NexaLanguage
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var editor: NexaPlistEditor
    let entry: NexaPlistEntry
    @State private var value: String
    @State private var saveError: String?

    init(editor: NexaPlistEditor, entry: NexaPlistEntry) {
        self.editor = editor
        self.entry = entry
        _value = State(initialValue: entry.valueText)
    }

    var body: some View {
        let en = language.code == "en"
        NavigationStack {
            Form {
                Section {
                    LabeledContent(en ? "Key" : "键名", value: entry.key)
                    LabeledContent(en ? "Type" : "类型", value: entry.kind.rawValue)
                }
                Section(en ? "Value" : "数值") {
                    TextEditor(text: $value)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                    if let saveError {
                        Text(saveError).font(.footnote).foregroundStyle(.red)
                    }
                    Text(en ? "The original imported copy is backed up before saving." :
                         "保存前会自动备份已导入文件的原始副本。")
                        .font(.footnote)
                }
            }
            .navigationTitle(en ? "Edit value" : "编辑属性值")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(en ? "Cancel" : "取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(en ? "Save" : "保存") {
                        if editor.save(entry: entry, text: value, language: language.code) {
                            dismiss()
                        } else {
                            saveError = editor.statusMessage
                            editor.statusMessage = nil
                        }
                    }
                }
            }
        }
    }
}
