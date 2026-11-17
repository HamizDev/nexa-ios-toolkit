import SwiftUI

struct SourceModule: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let repository: URL
    let status: String
    let note: String
}

enum ModuleCatalog {
    static let modules: [SourceModule] = [
        .init(id: "wqfiles", title: "WQ Files", subtitle: "文件与容器管理", symbol: "folder", repository: URL(string: "https://github.com/kolbicz/WQFiles")!, status: "接口预留", note: "当前只访问用户主动导入的文件；没有移植跨 App 容器浏览能力。"),
        .init(id: "wqtoolkit", title: "WQ Toolkit", subtitle: "存储分析与维护", symbol: "wrench.and.screwdriver", repository: URL(string: "https://github.com/MchinaMd57764/WQToolkit")!, status: "接口预留", note: "未合入上游实现。"),
        .init(id: "gestaltx", title: "GestaltX", subtitle: "MobileGestalt 配置", symbol: "slider.horizontal.3", repository: URL(string: "https://github.com/huamidev/GestaltX")!, status: "只读", note: "显示公开设备信息；不写入 MobileGestalt 或其他系统缓存。"),
        .init(id: "wcmigrate", title: "WCMigrate", subtitle: "聊天与应用数据迁移", symbol: "arrow.left.arrow.right", repository: URL(string: "https://github.com/yangokok886/WCMigrate")!, status: "安全备份", note: "现支持用户导入文件的备份、SHA-256 清单与校验；没有自动读取微信容器。"),
        .init(id: "erosion", title: "Erosion", subtitle: "外观与系统定制", symbol: "paintbrush.pointed", repository: URL(string: "https://github.com/jailbreakdotparty/Erosion")!, status: "研究候选", note: "当前未移植，不进行系统写入。"),
        .init(id: "regitela", title: "Regitela", subtitle: "文件与设备配置", symbol: "slider.horizontal.3", repository: URL(string: "https://github.com/ichitaso/Regitela")!, status: "研究候选", note: "当前未合入。"),
        .init(id: "worstgestalt", title: "WorstGestalt", subtitle: "设备能力编辑", symbol: "gearshape.2", repository: URL(string: "https://github.com/GoldensHQ/worstgestalt")!, status: "研究候选", note: "当前不写入系统缓存。"),
        .init(id: "worsefiles", title: "WorseFiles", subtitle: "中文文件管理", symbol: "folder.badge.gearshape", repository: URL(string: "https://github.com/fucknima/worsefiles-ios")!, status: "研究候选", note: "当前仅支持用户选择的文件。"),
        .init(id: "hermes", title: "HermesEnabler 2", subtitle: "Apple Watch 扩展", symbol: "applewatch", repository: URL(string: "https://github.com/pookjw/HermesEnabler")!, status: "待接入 watchOS target", note: "需要单独的手表原生 App、配对与签名，不能由 iPhone 单方面完成。")
    ]
}

struct ModuleTile: View {
    let module: SourceModule
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: module.symbol)
                    .font(.title2)
                    .foregroundStyle(.indigo)
                Spacer()
                Text(module.status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(module.title).font(.headline)
            Text(module.subtitle).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
