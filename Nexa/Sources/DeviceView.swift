import SwiftUI
import UIKit
import Darwin

enum NexaDeviceStatus {
    static func build() -> String {
        var chars = [CChar](repeating: 0, count: 32)
        var length = size_t(chars.count)
        let status = sysctlbyname("kern.osversion", &chars, &length, nil, 0)
        return status == 0 ? String(cString: chars) : "—"
    }

    static func compatibility(_ language: String) -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let en = language == "en"
        if v.majorVersion == 26 && (v.minorVersion < 7 || (v.minorVersion == 7 && v.patchVersion <= 2)) {
            return en ? "Within published range (unverified)" : "处于公开报告范围（未验证）"
        }
        if v.majorVersion == 27 && (v.minorVersion < 2 || (v.minorVersion == 2 && v.patchVersion <= 1)) {
            return en ? "Within published range (unverified)" : "处于公开报告范围（未验证）"
        }
        if v.majorVersion == 27 && v.minorVersion == 3 {
            if build() == "24C5037i" { return en ? "Beta 1: reported compatible" : "Beta 1：报告可用" }
            return en ? "Reported patched / not verified" : "已报告修复或未经验证"
        }
        return en ? "Unsupported or not verified" : "不支持或未经验证"
    }

    static func freeSpace() -> String {
        let size = (try? AppPaths.documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct DeviceView: View {
    @EnvironmentObject private var language: NexaLanguage

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("device.title"), subtitle: language.t("device.subtitle"))
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            info(language.t("device.name"), UIDevice.current.name)
                            info(language.t("device.family"), UIDevice.current.model)
                            info(language.t("device.system"), "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                            info(language.t("device.build"), NexaDeviceStatus.build())
                            info(language.t("device.region"), Locale.current.region?.identifier ?? "—")
                            info(language.t("device.memory"), ByteCountFormatter.string(fromByteCount: Int64(ProcessInfo.processInfo.physicalMemory), countStyle: .memory))
                            info(language.t("device.available"), NexaDeviceStatus.freeSpace())
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label(language.t("device.compat"), systemImage: "checkmark.shield")
                                .font(.headline)
                            NexaTag(text: NexaDeviceStatus.compatibility(language.code), color: NexaPalette.muted)
                            Text(language.t("device.compat.note"))
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Text(VersionSupport.contains(ProcessInfo.processInfo.operatingSystemVersion)
                                ? (language.code == "en" ? "GestaltX source targets iOS 27.x; no writes are enabled." : "GestaltX 上游目标为 iOS 27.x；Nexa 没有启用系统写入。")
                                : (language.code == "en" ? "GestaltX source does not target this OS version." : "GestaltX 上游源码未将此系统列为目标版本。"))
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                            Divider().overlay(.white.opacity(0.08))
                            HStack {
                                Text(language.t("device.mg"))
                                Spacer()
                                Text(language.t("device.mg.off"))
                                    .font(.caption).foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(language.t("device.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func info(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key).foregroundStyle(NexaPalette.muted)
            Spacer(minLength: 10)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
