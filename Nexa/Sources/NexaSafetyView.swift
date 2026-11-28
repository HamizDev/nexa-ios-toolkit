import SwiftUI

struct NexaSafetyView: View {
    @EnvironmentObject private var language: NexaLanguage
    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(title: en ? "Safety & scope" : "安全与使用说明",
                               subtitle: en ? "Know what each operation actually does." : "了解每项操作的实际作用与限制。")
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Development preview" : "开发预览版", systemImage: "exclamationmark.triangle")
                                .font(.headline).foregroundStyle(.orange)
                            Text(en ? "Nexa 0.0.1 has not passed full Xcode or device acceptance. It is not a released, signed IPA. Source-level integrations are not proof of runtime compatibility." :
                                 "Nexa 0.0.1 尚未完成 Xcode 编译及真机验收，不是已发布的签名 IPA。源码接入不等于已验证运行兼容性。")
                                .font(.footnote)
                        }
                    }
                    ForEach(NexaRisk.allCases, id: \.self) { risk in
                        NexaCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(risk.title(language.code), systemImage: risk == .readOnly ? "eye" : risk == .localChanges ? "folder.badge.gearshape" : "book")
                                    .font(.headline)
                                Text(risk.detail(language.code)).font(.footnote).foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Data and privacy" : "数据与隐私", systemImage: "lock.shield").font(.headline)
                            Text(en ? "Keep an independent backup before editing or deleting local copies. Deleting a backup or archive is permanent. Exported ZIPs are not encrypted, and SHA-256 manifests check consistency, not authenticity. Choose recipients carefully." :
                                 "编辑或删除本地副本之前，请另存独立备份。删除备份或归档属于永久操作。导出的 ZIP 未加密，SHA-256 清单仅用于一致性校验，不能证明来源真实性。请谨慎选择分享对象。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Text(en ? "Only choose data you own or have permission to handle. Nexa does not automatically upload files or access other apps' private data." :
                                 "仅选择你拥有或获得授权处理的数据。Nexa 不会自动上传文件，也不会访问其他 App 的私有数据。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Not implemented" : "未接入能力", systemImage: "nosign").font(.headline)
                            Text(en ? "System writes, cross-app private data access, full WeChat migration, watch-face modification and a native Nexa watchOS target are not available in this version." :
                                 "当前版本不提供系统写入、跨 App 私有数据访问、完整微信迁移、表盘修改或 Nexa 原生 watchOS Target。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Text(en ? "Published upstream compatibility reports do not establish device access. Prefer Apple security updates." :
                                 "上游兼容性报告不能证明当前设备具有访问权限，请优先考虑 Apple 的安全更新。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Disclaimer & licenses" : "免责声明与许可", systemImage: "doc.text").font(.headline)
                            Text(en ? "This open-source preview is provided as is, without a guarantee of fitness or data recovery. Review the licenses and the actual integration inventory before use." :
                                 "此开源预览版本按现状提供，不保证适用于特定用途或能够恢复数据。使用前请查阅许可证及实际接入清单。")
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Link(destination: URL(string: "https://github.com/HamizDev/nexa-ios-toolkit/blob/main/LICENSE")!) {
                                Label(en ? "Project license" : "项目许可证", systemImage: "arrow.up.right.square")
                            }
                            Link(destination: URL(string: "https://github.com/HamizDev/nexa-ios-toolkit/blob/main/Documentation/UPSTREAM_SOURCES.md")!) {
                                Label(en ? "Upstream inventory" : "上游接入清单", systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "Safety" : "安全说明")
        .navigationBarTitleDisplayMode(.inline)
    }
}
