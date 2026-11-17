import SwiftUI
import UIKit

struct DeviceView: View {
    @AppStorage("readOnlyMode") private var readOnlyMode = true

    var body: some View {
        List {
            Section("当前设备 · 公开信息") {
                LabeledContent("设备名称", value: UIDevice.current.name)
                LabeledContent("设备类别", value: UIDevice.current.model)
                LabeledContent("系统", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                LabeledContent("系统版本详情", value: ProcessInfo.processInfo.operatingSystemVersionString)
                LabeledContent("界面地区", value: Locale.current.region?.identifier ?? "未知")
                LabeledContent("总内存", value: ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
            }
            Section("MobileGestalt") {
                Label("设备能力与地区标记：保留未来适配接口", systemImage: "slider.horizontal.3")
                Label("当前版本不读取私有缓存、不修改系统配置", systemImage: "lock.shield")
                Text("修改设备标识与强制启用功能可能导致系统异常或重启循环。接入源项目后应先做完整备份、版本预检、差异预览与恢复验证。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("保护设置") {
                Toggle("默认只读模式", isOn: $readOnlyMode)
                Text("本工程没有系统写入模块。此开关用于为后续接入预留保护配置，不代表关闭后就能执行系统修改。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设备与配置")
    }
}
