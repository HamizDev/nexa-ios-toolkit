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

    let file: URL
    private var document: [String: Any] = [:]
    private let sizeLimit = 16 * 1024 * 1024

    init(file: URL) {
        self.file = file
        reload()
    }

    var filtered: [NexaPlistEntry] {
        guard !search.isEmpty else { return entries }
        return entries.filter {
            $0.key.localizedCaseInsensitiveContains(search) ||
            $0.valueText.localizedCaseInsensitiveContains(search)
        }
    }

    func reload() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            guard size <= sizeLimit else {
                throw NSError(domain: "Nexa.Plist", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Plist larger than 16 MB is not supported."])
            }
            let raw = try Data(contentsOf: file)
            guard let root = try PropertyListSerialization.propertyList(
                from: raw, options: [], format: nil
            ) as? [String: Any] else {
                throw NSError(domain: "Nexa.Plist", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Expected a dictionary property list."])
            }
            document = root
            editingCacheExtra = root["CacheExtra"] is [String: Any]
            let selected = (root["CacheExtra"] as? [String: Any]) ?? root
            entries = selected.keys.sorted().compactMap { key in
                guard let value = selected[key] else { return nil }
                let kind = PlistValueKind.detect(value)
                return NexaPlistEntry(key: key, kind: kind, valueText: kind.text(for: value))
            }
        } catch {
            statusMessage = error.localizedDescription
            entries = []
        }
    }

    func save(entry: NexaPlistEntry, text: String) -> Bool {
        do {
            // The parser comes directly from GestaltX. Parsing does not imply
            // permission to edit the original device MobileGestalt file.
            let parsed = try entry.kind.parse(text)
            var replacement = document
            if editingCacheExtra {
                guard var cache = replacement["CacheExtra"] as? [String: Any],
                      cache[entry.key] != nil else {
                    throw NSError(domain: "Nexa.Plist", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Source key changed. Reopen the file."])
                }
                cache[entry.key] = parsed
                replacement["CacheExtra"] = cache
            } else {
                guard replacement[entry.key] != nil else {
                    throw NSError(domain: "Nexa.Plist", code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "Source key changed. Reopen the file."])
                }
                replacement[entry.key] = parsed
            }

            let updated = try PropertyListSerialization.data(
                fromPropertyList: replacement, format: .binary, options: 0
            )
            guard updated.count <= sizeLimit else {
                throw NSError(domain: "Nexa.Plist", code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Result exceeds 16 MB."])
            }
            let raw = try Data(contentsOf: file)
            // Always retain a copy of the original imported file before writing.
            let backupRoot = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0].appendingPathComponent("Nexa/PlistEditBackups", isDirectory: true)
            try FileManager.default.createDirectory(
                at: backupRoot, withIntermediateDirectories: true
            )
            let backupURL = backupRoot.appendingPathComponent(UUID().uuidString + ".plist")
            try raw.write(to: backupURL, options: .atomic)
            try updated.write(to: file, options: .atomic)
            reload()
            statusMessage = "Saved an app-local plist copy. Original backed up as \(backupURL.lastPathComponent)."
            return true
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }
}

struct NexaPlistInspectorView: View {
    @EnvironmentObject private var language: NexaLanguage
    @StateObject private var editor: NexaPlistEditor
    @State private var active: NexaPlistEntry?

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
                        if editor.save(entry: entry, text: value) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
