import Foundation
import SwiftUI

// Intentionally limited to an explicitly selected, app-imported folder.
// The upstream WCMigrate parser is never given a private container or a
// non-authorized path. No account data is uploaded, cached, or written.
enum NexaImportedWeChatIdentity {
    enum CheckError: LocalizedError {
        case outOfScope
        case unsafeLinks
        case excessiveInput

        var errorDescription: String? {
            switch self {
            case .outOfScope: return "Choose a folder already imported into Nexa."
            case .unsafeLinks: return "This imported folder includes a symbolic link."
            case .excessiveInput: return "This import exceeds the safe account-inspection limits."
            }
        }
    }

    static func detect(in source: URL) throws -> String? {
        let fm = FileManager.default
        let importedRoot = AppPaths.importFolder.standardizedFileURL
        let folder = source.standardizedFileURL
        guard folder.path.hasPrefix(importedRoot.path + "/") else {
            throw CheckError.outOfScope
        }

        // Deny symlink traversal from the selected path back to the imported root.
        var node = folder
        while node.path != importedRoot.path {
            guard node.path.hasPrefix(importedRoot.path + "/") else { throw CheckError.outOfScope }
            let flags = try node.resourceValues(forKeys: [.isSymbolicLinkKey])
            guard flags.isSymbolicLink != true else { throw CheckError.unsafeLinks }
            node = node.deletingLastPathComponent()
        }

        let name = folder.lastPathComponent
        let isMD5 = name.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil
        let documents = name == "Documents" ? folder :
                        isMD5 ? folder.deletingLastPathComponent() :
                        folder.appendingPathComponent("Documents", isDirectory: true)
        guard fm.fileExists(atPath: documents.path) else { return nil }
        let dFlags = try documents.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard dFlags.isSymbolicLink != true, dFlags.isDirectory == true else {
            throw CheckError.unsafeLinks
        }

        let children = try fm.contentsOfDirectory(
            at: documents, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        let candidates = children.filter {
            $0.lastPathComponent.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil
        }
        guard candidates.count <= 128 else { throw CheckError.excessiveInput }
        for candidate in candidates {
            let flags = try candidate.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard flags.isSymbolicLink != true else { throw CheckError.unsafeLinks }
        }

        let loginFile = documents.appendingPathComponent("LoginInfo2.dat")
        guard fm.fileExists(atPath: loginFile.path) else { return nil }
        let flags = try loginFile.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        )
        guard flags.isSymbolicLink != true, flags.isRegularFile == true else {
            throw CheckError.unsafeLinks
        }
        guard (flags.fileSize ?? 0) <= 8 * 1024 * 1024 else {
            throw CheckError.excessiveInput
        }
        return WeChatIdentityResolver.preferredIdentifier(in: folder)
    }
}

struct NexaWeChatIdentityView: View {
    @EnvironmentObject private var language: NexaLanguage
    let folder: URL
    @State private var processing = false
    @State private var checked = false
    @State private var identifier: String?
    @State private var error: String?

    private var english: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(
                        title: english ? "WeChat identity inspector" : "微信账号身份检查",
                        subtitle: folder.lastPathComponent
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(english ? "Local imported data only" : "仅分析手动导入的数据",
                                  systemImage: "lock.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(english
                                ? "Uses WCMigrate's original LoginInfo2.dat parser. No other app's container is opened or changed. The detected account ID stays on this device."
                                : "直接使用 WCMigrate 上游 LoginInfo2.dat 解析器，不打开或修改其他 App 的容器，账号标识仅在本机显示。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaActionButton(
                        title: processing
                            ? (english ? "Inspecting…" : "正在检查…")
                            : (english ? "Inspect selected import" : "检查此导入文件夹"),
                        symbol: "person.crop.rectangle.stack"
                    ) {
                        analyze()
                    }
                    .disabled(processing)
                    if processing { ProgressView().tint(NexaPalette.mint) }
                    if let error {
                        NexaCard { Text(error).font(.footnote).foregroundStyle(.orange) }
                    }
                    if checked {
                        NexaCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(english ? "Identity result" : "账号识别结果")
                                    .font(.headline)
                                if let identifier {
                                    Text(identifier)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(NexaPalette.mint)
                                        .textSelection(.enabled)
                                } else {
                                    Text(english
                                        ? "No valid account identifier found. The selected folder may not contain the required original WeChat Documents structure."
                                        : "未识别到有效账号标识。所选文件夹可能缺少原始微信 Documents 结构。")
                                        .font(.footnote).foregroundStyle(NexaPalette.muted)
                                }
                            }
                        }
                    }
                    Text(english
                         ? "Identity detection is not a chat restore, database migration, or authorization to access other apps."
                         : "账号识别不等于聊天记录恢复、数据库迁移或获取其他 App 的访问权限。")
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                }
                .padding(20)
            }
        }
        .navigationTitle(english ? "WeChat ID" : "微信账号")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func analyze() {
        processing = true
        checked = false
        error = nil
        let chosen = folder
        Task {
            do {
                identifier = try await Task.detached(priority: .userInitiated) {
                    try NexaImportedWeChatIdentity.detect(in: chosen)
                }.value
                checked = true
            } catch {
                self.error = error.localizedDescription
            }
            processing = false
        }
    }
}
