import SwiftUI
import WatchConnectivity

struct WatchView: View {
    private var isPaired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

    var body: some View {
        List {
            Section("Apple Watch") {
                LabeledContent("已配对手表", value: isPaired ? "系统检测到配对" : "未检测到或不可用")
                Label("爱马仕表盘模块需要单独编译 watchOS App", systemImage: "applewatch")
            }
            Section("原始项目") {
                Link(destination: URL(string: "https://github.com/pookjw/HermesEnabler")!) {
                    Label("打开 HermesEnabler 2 源码", systemImage: "arrow.up.right.square")
                }
                Text("项目的实际兼容性取决于手表系统、签名和配对状态，请以原仓库说明为准。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("集成说明") {
                Text("这不是表盘解锁器：当前版本没有手表 target，也没有修改手表设备配置的代码。未来整合时需协调原有 watchOS target 与伴侣 App 的签名配置。")
                    .font(.subheadline)
            }
        }
        .navigationTitle("Apple Watch")
    }
}
