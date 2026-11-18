import SwiftUI
import Foundation

// Read-only, explicit-use UI backed by WQFiles' original WQAccess implementation.
// All advanced grants are scoped to user-requested folders, and require an
// eligible tested OS range plus a usable App Group signed into Nexa.
@MainActor
enum NexaContainerAccess {
    static var eligible: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        if v.majorVersion == 26 {
            return v.minorVersion < 7 || (v.minorVersion == 7 && v.patchVersion <= 2)
        }
        if v.majorVersion == 27 {
            if v.minorVersion < 2 { return true }
            if v.minorVersion == 2 { return v.patchVersion <= 1 }
            if v.minorVersion == 3 { return NexaDeviceStatus.build() == "24C5037i" }
        }
        return false
        #endif
    }

    static var signedGroup: String? {
        guard let group = wq_app_group() as String?, group.hasPrefix("group.") else { return nil }
        return group
    }

    static var ready: Bool { eligible && signedGroup != nil }

    static let approvedRoots = [
        "/var/mobile/Containers/Data/Application",
        "/private/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Shared/AppGroup",
        "/private/var/mobile/Containers/Shared/AppGroup"
    ]

    static func valid(_ path: String) -> Bool {
        guard !path.contains("\0"), !path.contains("\\"),
              path == path.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.dropFirst().allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else {
            return false
        }
        return approvedRoots.contains { path == $0 || path.hasPrefix($0 + "/") }
    }
}

struct NexaWQExplorerView: View {
    @EnvironmentObject private var language: NexaLanguage

    @State private var agreed = false
    @State private var currentPath = "/var/mobile/Containers/Data/Application"
    @State private var items: [String] = []
    @State private var busy = false
    @State private var message: String?
    @State private var preview: String?
    @State private var selectedRemote: String?
    @State private var importedCopy: URL?
    @State private var exportBusy = false

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    NexaHeader(
                        title: en ? "Container explorer" : "容器文件浏览",
                        subtitle: en ? "WQFiles upstream · Read-only preview" : "WQFiles 原生引擎 · 只读预览"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(en ? "Experimental / device only" : "实验性功能 / 仅真机",
                                  systemImage: "lock.shield")
                                .foregroundStyle(.orange)
                            Text(en ?
                                 "This uses the pinned WQFiles sandbox extension backend. It needs an eligible iOS build and an App Group provisioned for your signing team. It never scans other containers automatically and offers no file-write control. The upstream access mechanism may update this app's own App Group cache." :
                                 "该功能使用 WQFiles 原版容器访问引擎，要求匹配的 iOS 构建号及签名 App Group。不会自动扫描其他应用数据，也不提供文件写入操作；但上游授权机制可能修改本应用自己的 App Group 缓存。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                            Text(NexaContainerAccess.eligible
                                 ? (en ? "OS within upstream range (not device verified)" : "系统属于上游报告范围（尚未在本机验证）")
                                 : (en ? "Unsupported OS or simulator" : "系统版本不支持，或当前为模拟器"))
                                .font(.caption)
                            Text(NexaContainerAccess.signedGroup ??
                                 (en ? "No provisioned App Group detected" : "没有检测到可用的签名 App Group"))
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                                .textSelection(.enabled)
                        }
                    }
                    Toggle(
                        en ? "I own or am authorized to access the selected data; enable read-only exploration" :
                             "我拥有或获授权访问所选数据，同意开启只读浏览",
                        isOn: $agreed
                    )
                    .font(.footnote)
                    .tint(NexaPalette.mint)

                    Picker(en ? "Location" : "浏览位置", selection: $currentPath) {
                        Text(en ? "App data containers" : "应用数据容器")
                            .tag("/var/mobile/Containers/Data/Application")
                        Text(en ? "App Group containers" : "应用组容器")
                            .tag("/var/mobile/Containers/Shared/AppGroup")
                    }
                    .pickerStyle(.menu)
                    .disabled(busy)

                    TextField(en ? "Folder path" : "容器路径", text: $currentPath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.roundedBorder)

                    NexaActionButton(
                        title: en ? "Open selected folder" : "打开所选目录",
                        symbol: "folder.badge.gearshape"
                    ) { openCurrentFolder() }
                    .disabled(!agreed || !NexaContainerAccess.ready || busy || !NexaContainerAccess.valid(currentPath))

                    if busy { ProgressView().tint(NexaPalette.violet) }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(NexaPalette.muted)
                    }
                    if !items.isEmpty {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(items, id: \.self) { name in
                                    Button {
                                        openChild(name)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "doc.text.magnifyingglass")
                                                .foregroundStyle(NexaPalette.blue)
                                            Text(name)
                                                .font(.system(.caption, design: .monospaced))
                                                .lineLimit(2)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(NexaPalette.muted)
                                        }
                                        .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if let preview {
                        NexaCard {
                            Text(en ? "Read-only preview (up to 4 KB)" : "只读预览（最多 4 KB）")
                                .font(.headline)
                            Text(preview)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    if let selectedRemote {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(en ? "Selected file" : "已选择文件", systemImage: "doc.badge.arrow.down")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(NexaPalette.mint)
                                Text((selectedRemote as NSString).lastPathComponent)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                Text(en
                                     ? "The original WQFiles engine streams the selected file into a new Nexa copy. It never changes the remote file and rejects source changes during copying."
                                     : "原版 WQFiles 引擎会将此文件流式复制到新的 Nexa 副本，不修改源文件；复制期间来源发生变化则拒绝保留副本。")
                                    .font(.footnote)
                                    .foregroundStyle(NexaPalette.muted)
                                Button {
                                    exportRemote(selectedRemote)
                                } label: {
                                    Label(en ? "Copy into Nexa" : "复制到 Nexa 文件区",
                                          systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(NexaPalette.violet)
                                .disabled(!agreed || !NexaContainerAccess.ready || exportBusy || busy)
                                if exportBusy { ProgressView().tint(NexaPalette.mint) }
                                if let importedCopy {
                                    ShareLink(item: importedCopy) {
                                        Label(en ? "Share imported copy" : "分享已导入副本",
                                              systemImage: "square.and.arrow.up")
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Text(en ?
                         "Not an App Store feature. This implementation has not passed real-device acceptance tests." :
                         "非 App Store 常规权限功能；尚未通过真机验收。")
                        .font(.caption2)
                        .foregroundStyle(NexaPalette.muted)
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Container explorer" : "容器浏览")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: currentPath) { _, _ in
            selectedRemote = nil
            importedCopy = nil
        }
    }

    private func openCurrentFolder() {
        guard agreed && NexaContainerAccess.ready && NexaContainerAccess.valid(currentPath) else { return }
        busy = true
        message = nil
        preview = nil
        selectedRemote = nil
        importedCopy = nil
        let path = currentPath
        Task.detached(priority: .userInitiated) {
            var error: NSString?
            let found = wq_list(path, &error)
            await MainActor.run {
                items = found?.sorted() ?? []
                if found == nil { message = error as String? ?? (en ? "Access refused" : "访问被拒绝") }
                busy = false
            }
        }
    }

    private func openChild(_ name: String) {
        guard agreed && NexaContainerAccess.ready else { return }
        let path = (currentPath as NSString).appendingPathComponent(name)
        guard NexaContainerAccess.valid(path) else { return }
        busy = true
        preview = nil
        selectedRemote = nil
        importedCopy = nil
        Task.detached(priority: .userInitiated) {
            var error: NSString?
            if let contents = wq_list(path, &error) {
                await MainActor.run {
                    currentPath = path
                    items = contents.sorted()
                    busy = false
                }
            } else {
                // Never read more than 4 KB of an explicitly selected file.
                error = nil
                let bytes = wq_read(path, 4096, &error)
                let text = bytes.map { String(data: $0 as Data, encoding: .utf8) ?? ($0 as Data).map { String(format: "%02X", $0) }.joined(separator: " ") }
                await MainActor.run {
                    preview = text ?? (error as String? ?? (en ? "Unreadable file" : "无法读取文件"))
                    selectedRemote = bytes != nil ? path : nil
                    busy = false
                }
            }
        }
    }

    private func exportRemote(_ remote: String) {
        guard agreed, !busy, !exportBusy, NexaContainerAccess.ready,
              NexaContainerAccess.valid(remote), selectedRemote == remote else { return }
        exportBusy = true
        importedCopy = nil
        message = nil
        Task {
            do {
                let saved = try await Task.detached(priority: .userInitiated) {
                    try NexaWQFileExport.copySelectedRemoteFile(remote)
                }.value
                importedCopy = saved
                message = en
                    ? "Verified file copied into Nexa Imports: \(saved.lastPathComponent)"
                    : "已校验复制到 Nexa 导入区：\(saved.lastPathComponent)"
            } catch {
                message = error.localizedDescription
            }
            exportBusy = false
        }
    }
}
