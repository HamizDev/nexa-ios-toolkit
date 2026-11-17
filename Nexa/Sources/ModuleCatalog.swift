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
        .init(id: "wqfiles", title: "WQFiles", subtitleZh: "文件检查与十六进制解析", subtitleEn: "File inspection & hex parsing", detailsZh: "已接入原版 WQCore 十六进制校验与 WQArchive ZIP 压缩／解压，用于 Nexa 已导入的文件。仍未接入跨容器授权、App 数据浏览和缓存清理。", detailsEn: "The original WQCore hex validator and WQArchive ZIP engine are compiled and used for imported files. Cross-container access, app-data browsing and cache cleaning are not integrated.", symbol: "doc.text.magnifyingglass", repository: URL(string: "https://github.com/kolbicz/WQFiles")!, phase: .partial),
        .init(id: "wqtoolkit", title: "WQToolkit", subtitleZh: "自身容器诊断及维护", subtitleEn: "Owned-container diagnostics", detailsZh: "上游 README 将功能限定为自己的数据容器和 App Group。Nexa 暂未移植其系统维护、缓存扫描和写入组件，且需要进一步确认授权声明。", detailsEn: "Upstream scope is limited to app-owned containers and App Groups. Its maintenance, cache scanning and write components are not integrated, and licensing requires review.", symbol: "wrench.and.screwdriver", repository: URL(string: "https://github.com/MchinaMd57764/WQToolkit")!, phase: .research),
        .init(id: "gestaltx", title: "GestaltX", subtitleZh: "MobileGestalt 与设备能力", subtitleEn: "MobileGestalt & capabilities", detailsZh: "已编译 GestaltX 的版本检查代码，并用于设备页的只读兼容提示。MobileGestalt 缓存读取、修改和回滚仍未移植。", detailsEn: "GestaltX's upstream version helper is compiled and used for read-only compatibility labeling. Cache access, writes and rollback are not integrated.", symbol: "slider.horizontal.3", repository: URL(string: "https://github.com/huamidev/GestaltX")!, phase: .partial),
        .init(id: "wcmigrate", title: "WCMigrate", subtitleZh: "个人应用数据备份与迁移", subtitleEn: "User data backup & migration", detailsZh: "已编译 WCMigrate 的原始进度估算与只读 SQLite 数据库检查代码，接入 Nexa 的本地备份。微信多开迁移、数据库语义合并和跨容器访问尚未实现。", detailsEn: "WCMigrate's original progress/ETA and read-only SQLite quick_check engine are compiled into Nexa's local backups. Cross-app data transfer, WeChat record merging and container access remain unavailable.", symbol: "arrow.left.arrow.right", repository: URL(string: "https://github.com/yangokok886/WCMigrate")!, phase: .partial),
        .init(id: "erosion", title: "Erosion", subtitleZh: "界面外观与系统定制", subtitleEn: "Appearance & system customization", detailsZh: "项目作为后续兼容性及安全回滚研究对象，目前没有系统写入功能。", detailsEn: "Tracked for compatibility and safe rollback research. No system writes are available.", symbol: "paintbrush.pointed", repository: URL(string: "https://github.com/jailbreakdotparty/Erosion")!, phase: .research),
        .init(id: "regitela", title: "Regitela", subtitleZh: "文件管理与设备设置", subtitleEn: "File utilities & device settings", detailsZh: "尚未移植 Regitela 的文件或系统配置代码。", detailsEn: "Regitela file and system configuration code has not been integrated.", symbol: "gearshape.2", repository: URL(string: "https://github.com/ichitaso/Regitela")!, phase: .pending),
        .init(id: "worstgestalt", title: "WorstGestalt", subtitleZh: "配置预设与备份恢复", subtitleEn: "Presets, backups & recovery", detailsZh: "未集成其 MobileGestalt 写入引擎或配置预设；任何将来的系统更改必须先通过风险审核。", detailsEn: "The MobileGestalt write engine and presets are not integrated. Future changes require a safety review.", symbol: "square.stack.3d.up", repository: URL(string: "https://github.com/GoldensHQ/worstgestalt")!, phase: .pending),
        .init(id: "worsefiles", title: "WorseFiles", subtitleZh: "中文文件浏览和备份工具", subtitleEn: "Localized file browser & backup", detailsZh: "目前没有移植 WorseFiles 的跨容器文件操作。Nexa 自有文件管理功能仅作用于已导入的文件。", detailsEn: "Cross-container operations from WorseFiles are not integrated. Nexa's own browser is limited to imported files.", symbol: "folder.badge.gearshape", repository: URL(string: "https://github.com/fucknima/worsefiles-ios")!, phase: .research),
        .init(id: "hermes", title: "HermesEnabler 2", subtitleZh: "Apple Watch 伴侣 App", subtitleEn: "Apple Watch companion app", detailsZh: "已建立真实的 WatchConnectivity 会话监测，显示配对及安装状态。HermesEnabler 上游源码以固定版本保留。Nexa 已新增可随 iPhone App 嵌入的独立 watchOS Target，支持双向连接诊断；表盘修改引擎尚未移植。", detailsEn: "Live WatchConnectivity pairing/session monitoring is wired in. The original HermesEnabler source is pinned separately. Nexa now includes an embedded watchOS companion target with bidirectional connectivity diagnostics, but the watch-face engine is not integrated.", symbol: "applewatch", repository: URL(string: "https://github.com/pookjw/HermesEnabler")!, phase: .pending)
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
                    Text(module.phase.label(language)).font(.caption2.weight(.medium)).foregroundStyle(module.phase.color)
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
}
