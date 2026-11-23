import SwiftUI

enum ModulePhase {
    case partial
    case research
    case pending

    @MainActor func label(_ language: NexaLanguage) -> String {
        switch self {
        case .partial: return language.t("module.safe")
        case .research: return language.t("common.research")
        case .pending: return language.t("module.upstream")
        }
    }

    var color: Color {
        switch self {
        case .partial: return NexaPalette.mint
        case .research: return NexaPalette.blue
        case .pending: return NexaPalette.violet
        }
    }
}

struct SourceModule: Identifiable {
    let id: String
    let title: String
    let subtitleZh: String
    let subtitleEn: String
    let detailsZh: String
    let detailsEn: String
    let symbol: String
    let repository: URL
    let phase: ModulePhase

    func subtitle(_ code: String) -> String { code == "en" ? subtitleEn : subtitleZh }
    func details(_ code: String) -> String { code == "en" ? detailsEn : detailsZh }
}

enum ModuleCatalog {
    static let modules: [SourceModule] = [
        .init(id: "wqfiles", title: "WQFiles", subtitleZh: "文件检查与十六进制解析", subtitleEn: "File inspection & hex parsing", detailsZh: "已接入原版 WQCore 十六进制校验与 WQArchive ZIP 压缩／解压，用于 Nexa 已导入的文件。已加入 WQAccess 原版引擎和需明确授权的实验性只读容器浏览入口，但尚未完成真机授权验证；缓存清理与跨容器写入仍未启用。", detailsEn: "The original WQCore hex validator and WQArchive ZIP engine are compiled and used for imported files. The original WQAccess engine and a consent-gated read-only container browser are now included, but real-device grants are unverified; cache cleaning and cross-app writes remain disabled.", symbol: "doc.text.magnifyingglass", repository: URL(string: "https://github.com/kolbicz/WQFiles")!, phase: .partial),
        .init(id: "wqtoolkit", title: "WQToolkit", subtitleZh: "自身容器诊断及维护", subtitleEn: "Owned-container diagnostics", detailsZh: "上游 README 将功能限定为自己的数据容器和 App Group。Nexa 暂未移植其系统维护、缓存扫描和写入组件，且需要进一步确认授权声明。", detailsEn: "Upstream scope is limited to app-owned containers and App Groups. Its maintenance, cache scanning and write components are not integrated, and licensing requires review.", symbol: "wrench.and.screwdriver", repository: URL(string: "https://github.com/MchinaMd57764/WQToolkit")!, phase: .research),
        .init(id: "gestaltx", title: "GestaltX", subtitleZh: "MobileGestalt 与设备能力", subtitleEn: "MobileGestalt & capabilities", detailsZh: "已编译 GestaltX 的版本检查、原版系统库只读数据段检查与 plist 类型解析代码；设备页可手动检查已加载系统库的摘要。系统 MobileGestalt 缓存写入和回滚仍未移植。", detailsEn: "GestaltX's original version helper, read-only loaded-library image inspector and plist parser are compiled into Nexa. On-disk MobileGestalt cache writes and rollback are not integrated.", symbol: "slider.horizontal.3", repository: URL(string: "https://github.com/huamidev/GestaltX")!, phase: .partial),
        .init(id: "wcmigrate", title: "WCMigrate", subtitleZh: "个人应用数据备份与迁移", subtitleEn: "User data backup & migration", detailsZh: "已编译 WCMigrate 的原始进度估算与只读 SQLite 数据库检查代码，接入 Nexa 的本地备份；Nexa 自己还实现了带安全快照和中断恢复的本地备份恢复与已导入文件夹之间的逐文件哈希校验迁移；已添加 LoginInfo2.dat 微信账号识别；另外支持对 Nexa 导入副本执行不覆盖原件的文件级合并／替换。上游的跨 App 替换／转换／文件级合并引擎尚未接入；上游本身也不支持 SQLite 聊天记录行级合并或整任务回滚。", detailsEn: "WCMigrate's original progress/ETA and read-only SQLite quick_check engine support Nexa backups, alongside Nexa's own journaled restore, verified imported-folder migration, source-preserving local file-level Merge/Replace snapshots, and on-demand imported WeChat identity detection. The original live Replace/Convert/file-level Merge engine is not integrated; upstream itself does not provide SQLite chat-record row merging or whole-task rollback.", symbol: "arrow.left.arrow.right", repository: URL(string: "https://github.com/yangokok886/WCMigrate")!, phase: .partial),
        .init(id: "erosion", title: "Erosion", subtitleZh: "界面外观与系统定制", subtitleEn: "Appearance & system customization", detailsZh: "项目作为后续兼容性及安全回滚研究对象，目前没有系统写入功能。", detailsEn: "Tracked for compatibility and safe rollback research. No system writes are available.", symbol: "paintbrush.pointed", repository: URL(string: "https://github.com/jailbreakdotparty/Erosion")!, phase: .research),
        .init(id: "regitela", title: "Regitela", subtitleZh: "文件管理与设备设置", subtitleEn: "File utilities & device settings", detailsZh: "尚未移植 Regitela 的文件或系统配置代码。", detailsEn: "Regitela file and system configuration code has not been integrated.", symbol: "gearshape.2", repository: URL(string: "https://github.com/ichitaso/Regitela")!, phase: .pending),
        .init(id: "worstgestalt", title: "WorstGestalt", subtitleZh: "配置预设与备份恢复", subtitleEn: "Presets, backups & recovery", detailsZh: "未集成其 MobileGestalt 写入引擎或配置预设；任何将来的系统更改必须先通过风险审核。", detailsEn: "The MobileGestalt write engine and presets are not integrated. Future changes require a safety review.", symbol: "square.stack.3d.up", repository: URL(string: "https://github.com/GoldensHQ/worstgestalt")!, phase: .pending),
        .init(id: "worsefiles", title: "WorseFiles", subtitleZh: "中文文件浏览和备份工具", subtitleEn: "Localized file browser & backup", detailsZh: "目前没有移植 WorseFiles 的跨容器文件操作。Nexa 自有文件管理功能仅作用于已导入的文件。", detailsEn: "Cross-container operations from WorseFiles are not integrated. Nexa's own browser is limited to imported files.", symbol: "folder.badge.gearshape", repository: URL(string: "https://github.com/fucknima/worsefiles-ios")!, phase: .research),
        .init(id: "hermes", title: "HermesEnabler 2", subtitleZh: "Apple Watch 伴侣 App", subtitleEn: "Apple Watch companion app", detailsZh: "现已直接编译 HermesEnabler 固定上游提交里的 iPhone 原版 WatchConnectivity 备份管理器，提供原版 SHA-256 备份历史、plist 导入／导出、验证和排队发送到 Watch。iPhone 端仅保留原版管理器一个 WCSession 代理，并增加 Nexa Ping 适配。Watch 端继续使用原版 Hermes 引擎和功能面板；真实配对传输、签名、系统修改与恢复尚未通过真机验收。", detailsEn: "The pinned original HermesCompanion iPhone WatchConnectivity manager is now directly compiled into Nexa and provides SHA-256 backup history, plist import/export, verification and queued transfer to Watch, with one iPhone WCSession delegate and a thin Nexa Ping adapter. The embedded Watch BQCore and panels remain original; physical backup transport, signed App Groups, system modifications and restore remain unverified.", symbol: "applewatch", repository: URL(string: "https://github.com/pookjw/HermesEnabler")!, phase: .partial)
    ]

    static var highlighted: [SourceModule] {
        modules.filter { ["wqfiles", "gestaltx", "wcmigrate"].contains($0.id) }
    }
}

struct ModuleRow: View {
    @EnvironmentObject private var language: NexaLanguage
    let module: SourceModule

    var body: some View {
        NexaCard {
            HStack(spacing: 13) {
                Image(systemName: module.symbol)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(module.phase.color)
                    .frame(width: 44, height: 44)
                    .background(module.phase.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(module.title).font(.subheadline.weight(.semibold))
                    Text(module.subtitle(language.code)).font(.caption).foregroundStyle(NexaPalette.muted)
                    HStack(spacing: 6) {
                        Text(module.phase.label(language))
                            .foregroundStyle(module.phase.color)
                        if let risk = NexaSafetyCatalog.entry(for: module.id) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(risk.severity.color)
                                .accessibilityLabel(risk.severity.label(language.code == "en"))
                        }
                    }
                    .font(.caption2.weight(.medium))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(NexaPalette.muted)
            }
        }
    }
}

struct ModulesView: View {
    @EnvironmentObject private var language: NexaLanguage

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    NexaHeader(title: language.t("module.title"), subtitle: language.t("module.subtitle"))
                    ForEach(ModuleCatalog.modules) { module in
                        NavigationLink(destination: ModuleDetailView(module: module)) {
                            ModuleRow(module: module)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(language.t("module.warning"))
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                        .padding(.vertical, 16)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ModuleDetailView: View {
    @EnvironmentObject private var language: NexaLanguage
    let module: SourceModule

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Image(systemName: module.symbol)
                                .font(.system(size: 40))
                                .foregroundStyle(module.phase.color)
                            Text(module.title).font(.largeTitle.weight(.bold))
                            Text(module.subtitle(language.code)).foregroundStyle(NexaPalette.muted)
                            NexaTag(text: module.phase.label(language), color: module.phase.color)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(module.details(language.code))
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            Link(destination: module.repository) {
                                Label(language.t("common.source"), systemImage: "arrow.up.right.square")
                                    .font(.callout.weight(.medium))
                            }
                        }
                    }
                    if let risk = NexaSafetyCatalog.entry(for: module.id) {
                        NexaRiskNotice(risk: risk, detailed: true)
                    }
                    moduleActions
                    if module.phase != .partial {
                        Text(language.t("module.warning"))
                            .font(.footnote).foregroundStyle(NexaPalette.muted)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(module.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // A genuine in-app action for every currently integrated toolkit.
    // Watch system modification is only accessible on the paired Watch under
    // its own build and App Group gate, not by tapping the iPhone card.
    @ViewBuilder
    private var moduleActions: some View {
        let en = language.code == "en"
        switch module.id {
        case "wqfiles":
            NavigationLink {
                FilesView()
            } label: {
                Label(en ? "Open file workspace" : "打开文件工作台", systemImage: "folder.fill")
            }
            .buttonStyle(.borderedProminent)
        case "gestaltx":
            NavigationLink {
                DeviceView()
            } label: {
                Label(en ? "Open device diagnostics" : "打开设备诊断",
                      systemImage: "iphone.gen3")
            }
            .buttonStyle(.borderedProminent)
            NavigationLink {
                FilesView()
            } label: {
                Label(en ? "Inspect imported plist" : "查看已导入属性列表",
                      systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
        case "wcmigrate":
            NavigationLink {
                NexaMigrationView()
            } label: {
                Label(en ? "Open local migration" : "打开本地迁移",
                      systemImage: "arrow.left.arrow.right.square")
            }
            .buttonStyle(.borderedProminent)
            NavigationLink {
                BackupView()
            } label: {
                Label(en ? "Open backup and restore" : "打开备份与恢复",
                      systemImage: "externaldrive.fill")
            }
            .buttonStyle(.bordered)
        case "hermes":
            NavigationLink {
                WatchView()
            } label: {
                Label(en ? "Watch companion diagnostics" : "手表连接与诊断",
                      systemImage: "applewatch")
            }
            .buttonStyle(.borderedProminent)
        default:
            EmptyView()
        }
    }
}
