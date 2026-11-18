import SwiftUI

/// Risk information is separate from the integration status. Upstream support
/// does not imply that a corresponding operation is implemented or verified in Nexa.
enum NexaSafetyCatalog {
    enum Severity {
        case caution, high, critical

        var color: Color {
            switch self {
            case .caution: return NexaPalette.blue
            case .high: return .orange
            case .critical: return .red
            }
        }

        func label(_ en: Bool) -> String {
            switch self {
            case .caution: return en ? "Caution" : "注意"
            case .high: return en ? "High risk" : "高风险"
            case .critical: return en ? "System / data risk" : "系统／数据风险"
            }
        }
    }

    struct Entry: Identifiable {
        let id: String
        let name: String
        let severity: Severity
        let upstreamZh: String
        let upstreamEn: String
        let integratedZh: String
        let integratedEn: String
        let upstreamURL: URL

        func upstream(_ en: Bool) -> String { en ? upstreamEn : upstreamZh }
        func integrated(_ en: Bool) -> String { en ? integratedEn : integratedZh }
    }

    // Risk statements are taken from the pinned upstream READMEs, or clearly
    // marked as Nexa-specific cautions where no upstream warning is available.
    static let entries: [Entry] = [
        Entry(
            id: "wqfiles", name: "WQFiles", severity: .high,
            upstreamZh: "上游警告：worse_query 在 iOS 27.3 Beta 2（24C5049d）及后续版本已修复。跨容器读取依赖特定系统构建与授权。上游的覆盖／删除会先备份文件，但“清空应用数据”和“缓存清理”并无逐文件备份，部分数据可能无法恢复；操作其他 App 数据前应关闭目标 App。",
            upstreamEn: "Upstream warning: worse_query is patched from iOS 27.3 beta 2 (24C5049d). Cross-container access depends on the precise build and authorization. Upstream file overwrites/deletes normally create backups, but app-data clearing and cache cleaning have no file-by-file backup and may be irreversible. Close the target app first.",
            integratedZh: "Nexa 已接入原版 ZIP、十六进制工具，以及受授权与版本限制的只读浏览／选定文件复制。远程覆盖、删除、缓存清理尚未接入；跨容器权限未经过真机验证。",
            integratedEn: "Nexa includes upstream ZIP/hex utilities and a gated read-only browser with selected-file import. Remote writes, deletion and cache cleaning are not integrated. Cross-container access has not been verified on real devices.",
            upstreamURL: URL(string: "https://github.com/kolbicz/WQFiles#safety")!
        ),
        Entry(
            id: "wcmigrate", name: "WCMigrate", severity: .critical,
            upstreamZh: "上游风险：替换可能删除目标目录的额外内容，合并会覆盖同名文件，转换／未开启“保留来源”的迁移可能直接移动原文件。上游明确提醒暂存期间不要卸载 WCMigrate；修改或删除 manifest.json、payload 会影响备份校验与恢复。上游不保证整任务回滚，文件合并并非 SQLite 聊天记录行级合并，Keychain／登录态也不会迁移；iOS 27.3 尚未经过上游真机验证。",
            upstreamEn: "Upstream risks: Replace may delete extra target content, Merge overwrites namesakes, and Convert or transfers without Keep Source may move original files. The upstream README warns not to uninstall WCMigrate during staging. Altering manifest.json or payload can break validation/recovery. Upstream does not provide whole-task rollback or SQLite chat-record row merging, and does not transfer Keychain/login state; iOS 27.3 lacked device validation in the pinned README.",
            integratedZh: "Nexa 当前仅提供用户已导入数据的保留来源副本迁移、哈希校验、备份与身份检查。原版实时微信跨 App 替换／转换／合并引擎尚未接入，不应当作微信恢复工具。",
            integratedEn: "Nexa currently provides source-preserving, hash-verified copies only for user-imported data, plus backup/identity helpers. The original live WeChat Replace/Convert/Merge engine is not integrated and this is not a live WeChat restore.",
            upstreamURL: URL(string: "https://github.com/yangokok886/WCMigrate#%E5%8A%9F%E8%83%BD")!
        ),
        Entry(
            id: "gestaltx", name: "GestaltX", severity: .critical,
            upstreamZh: "Nexa 安全提示：更改系统 MobileGestalt 缓存可能影响设备功能或造成异常，应只在确认支持的设备上、保留原始备份并验证恢复路径后操作。此为系统修改风险说明，不代表上游 README 已保证某种设备兼容性。",
            upstreamEn: "Nexa safety assessment: modifying a device's MobileGestalt cache can affect device capabilities or stability. Such operations require a verified device/build, an original backup and a tested restore path. This warning is Nexa's risk assessment, not an upstream compatibility guarantee.",
            integratedZh: "Nexa 目前仅有导入副本的离线 plist 编辑、历史恢复，以及已加载系统库的只读诊断。系统 MobileGestalt 修改和回滚尚未实现。",
            integratedEn: "Nexa only edits imported plist copies with versioned undo and shows read-only loaded-library diagnostics. On-device MobileGestalt changes and system rollback are not implemented.",
            upstreamURL: URL(string: "https://github.com/huamidev/GestaltX")!
        ),
        Entry(
            id: "hermes", name: "HermesEnabler 2", severity: .critical,
            upstreamZh: "上游明确警告：卸载前应先通过 HermesEnabler2 恢复 MobileGestalt 备份；更新时应保持相同 Bundle ID 与 Apple ID，以免丢失 App 数据和备份。watchOS 26 仅属实验性支持；需要配对手表和具有 App Groups 权限的开发者签名。上游写明“使用风险自负”。",
            upstreamEn: "Upstream cautions: restore the MobileGestalt backup in HermesEnabler2 BEFORE uninstalling; keep the same Bundle ID and Apple ID across updates to preserve data and backups. watchOS 26 support is experimental; a paired Watch and paid Apple Developer App Groups entitlement are required. Upstream states 'Use at your own risk.'",
            integratedZh: "原版 Watch 引擎和界面已编入 NexaWatch，Nexa 限制实验入口为更保守的 watchOS 27.0–27.2，并要求 App Group 与明确同意；实际表盘修改、原始备份与回滚均未通过真机验收。",
            integratedEn: "The original Watch engine and UI compile in NexaWatch. Nexa gates the experimental entry to watchOS 27.0–27.2, a working App Group and consent. Actual face changes, backups and rollback remain unverified on real hardware.",
            upstreamURL: URL(string: "https://github.com/pookjw/HermesEnabler#cautions")!
        )
    ]

    static func entry(for moduleID: String) -> Entry? {
        entries.first { $0.id == moduleID }
    }
}

struct NexaRiskNotice: View {
    @EnvironmentObject private var language: NexaLanguage
    let risk: NexaSafetyCatalog.Entry
    var detailed: Bool = false

    private var en: Bool { language.code == "en" }

    var body: some View {
        NexaCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(risk.severity.color)
                    Text(risk.name + " · " + risk.severity.label(en))
                        .font(.headline)
                        .foregroundStyle(risk.severity.color)
                }
                Text(risk.upstream(en))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if detailed {
                    Divider().overlay(.white.opacity(0.10))
                    Label(en ? "Currently available in Nexa" : "Nexa 实际接入状态",
                          systemImage: "checkmark.circle")
                        .font(.subheadline.weight(.semibold))
                    Text(risk.integrated(en))
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Link(destination: risk.upstreamURL) {
                        Label(en ? "Check upstream risk notes" : "查看上游说明与风险",
                              systemImage: "arrow.up.right.square")
                            .font(.footnote)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

struct NexaDisclaimerView: View {
    @EnvironmentObject private var language: NexaLanguage
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nexa.safety.disclaimer.read.0.0.1") private var read = false
    @State private var confirmed = false

    var requiresAcknowledgment = false
    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(
                        title: en ? "Disclaimer & safety" : "免责声明与风险说明",
                        subtitle: en ? "Nexa 0.0.1 · Developer preview" : "Nexa 0.0.1 · 开发预览版"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(en ? "Not a complete or validated system tool" :
                                  "并非完整或已验收的系统工具",
                                  systemImage: "exclamationmark.triangle.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            Text(en
                                ? "Nexa combines selected upstream components. An upstream feature being described as stable does not mean its Nexa integration is complete, permitted by your OS, or safe on your device. No guarantee of uninterrupted operation, data integrity or compatibility is made."
                                : "Nexa 集成了部分上游组件。上游宣称某项功能稳定，并不代表该功能在 Nexa 中已完整接入、获得当前系统权限或经过真机安全验证。本开发版不保证持续可用、数据完整或设备兼容。")
                            Text(en
                                ? "System customization, third-party app data operations, backup replacement and Watch changes can cause data loss, app failures or device instability. Create an independent, restorable backup before any high-risk operation. Verify that you own or are authorized to access the selected files."
                                : "系统定制、跨应用数据操作、备份替换及手表修改可能造成数据丢失、应用异常或设备不稳定。进行任何高风险操作前，应先建立独立且可恢复的备份，并确认你有权访问所选数据。")
                            Text(en
                                ? "Do not use experimental functions with irreplaceable data or on an unsupported OS build. Restore an original MobileGestalt backup before uninstalling an app that modified it. Confirm the actual in-app feature status; a compiled source module is not proof that it works on real hardware."
                                : "请勿在不受支持的系统构建或不可替代的数据上尝试实验功能。若使用了修改 MobileGestalt 的工具，应在卸载前先恢复原始备份。请以应用实际功能状态为准：源码可编译不代表真机已可用。")
                            Text(en
                                ? "This notice describes technical risks, not a waiver of any rights or responsibilities that cannot legally be waived."
                                : "本说明用于告知技术风险，不排除法律规定不可免除的责任，也不要求用户放弃依法享有的权利。")
                                .foregroundStyle(NexaPalette.muted)
                        }
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(en ? "Specific upstream cautions and Nexa status" : "各上游项目的具体警告及 Nexa 状态")
                        .font(.title3.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(NexaSafetyCatalog.entries) { item in
                        NexaRiskNotice(risk: item, detailed: true)
                    }
                    if requiresAcknowledgment {
                        Toggle(
                            en ? "I have read these warnings and will verify backups before risky operations." :
                                 "我已阅读风险提示，进行高风险操作前会确认备份可恢复。",
                            isOn: $confirmed
                        )
                        .font(.footnote)
                        .tint(NexaPalette.mint)
                        .padding(.vertical, 10)
                    }
                    Text(en
                         ? "Sources: pinned upstream READMEs and Nexa's actual implementation. You can reopen this page from Settings at any time."
                         : "依据：固定版本的上游 README 与 Nexa 当前实际实现。可随时从“设置”重新阅读本页。")
                        .font(.caption)
                        .foregroundStyle(NexaPalette.muted)
                        .padding(.bottom, 18)
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Safety & disclaimer" : "安全与免责声明")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if requiresAcknowledgment {
                Button {
                    read = true
                    dismiss()
                } label: {
                    Label(en ? "I have read this — continue" : "我已阅读，继续使用",
                          systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(NexaPalette.violet)
                .disabled(!confirmed)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(NexaPalette.ink2)
            }
        }
        .interactiveDismissDisabled(requiresAcknowledgment)
    }
}
