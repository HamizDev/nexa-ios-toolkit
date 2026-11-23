import SwiftUI
import Foundation

// This is deliberately NOT the full WQAppsViewController: upstream WQApps.m
// includes backup, restore, clear and delete actions without a global
// readOnly switch. Instead, Nexa directly calls the ORIGINAL read-only
// WQLaunchServices parser + original WQAppsSupport Bundle ID validator.
// The list is explicitly user-requested, no full inode/container scan runs,
// and opening an entry requires a second consent in NexaWQExplorerView.
struct NexaWQAppCatalogView: View {
    @EnvironmentObject private var language: NexaLanguage

    struct AppRecord: Identifiable, Sendable {
        let id: String // Original LaunchServices container path, no mutation
        let bundleID: String
        let displayName: String
    }

    @State private var agreed = false
    @State private var loading = false
    @State private var apps: [AppRecord] = []
    @State private var searchText = ""
    @State private var message: String?

    private var en: Bool { language.code == "en" }

    private var filteredApps: [AppRecord] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.bundleID.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NexaHeader(
                        title: en ? "App catalog" : "应用目录",
                        subtitle: en
                            ? "Original WQFiles LaunchServices · metadata only"
                            : "WQFiles 原版 LaunchServices · 仅元数据"
                    )
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Experimental / device only" : "实验性／仅真机",
                                  systemImage: "lock.shield")
                                .foregroundStyle(.orange)
                            Text(en
                                ? "Uses the original WQLaunchServices database parser and WQAppsSupport bundle-ID checks. No full filesystem scan and no App data deletion, backup or restore is provided. Looking up names may use the original sandbox grant and this app's own App Group cache."
                                : "直接调用 WQLaunchServices 原版数据库解析器与 WQAppsSupport 原版 Bundle ID 校验。不执行全文件系统枚举，也不提供其他 App 数据删除、备份或恢复；查找名称可能使用原版沙盒授权并更新 Nexa 自身的 App Group 缓存。")
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                            Text(NexaContainerAccess.ready
                                ? (en ? "Compatible access gate detected, device still unverified"
                                      : "检测到兼容条件，但真机访问能力尚未验证")
                                : (en ? "Unavailable on simulator / unsupported build / missing App Group"
                                      : "模拟器、不兼容系统或缺少 App Group，无法使用"))
                                .font(.caption)
                                .foregroundStyle(NexaPalette.muted)
                            if let group = NexaContainerAccess.signedGroup {
                                Text(group).font(.caption2.monospaced())
                                    .foregroundStyle(NexaPalette.muted)
                            }
                        }
                    }
                    if let risk = NexaSafetyCatalog.entry(for: "wqfiles") {
                        NexaRiskNotice(risk: risk)
                    }
                    Toggle(isOn: $agreed) {
                        Text(en
                            ? "I own or am authorized to inspect the selected app metadata and containers."
                            : "我拥有或获授权查看相关 App 元数据与容器。")
                            .font(.footnote)
                    }
                    .tint(NexaPalette.mint)
                    NexaActionButton(
                        title: en ? "Load app catalog" : "读取应用目录",
                        symbol: "apps.iphone"
                    ) { loadCatalog() }
                    .disabled(!agreed || !NexaContainerAccess.ready || loading)
                    if loading {
                        ProgressView(en ? "Reading upstream metadata…" : "正在读取上游元数据…")
                            .tint(NexaPalette.mint)
                    }
                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(NexaPalette.muted)
                    }
                    if !apps.isEmpty {
                        NexaSearchField(
                            placeholder: en ? "Search app names or bundle IDs" : "搜索 App 名称或 Bundle ID",
                            text: $searchText,
                            clearLabel: en ? "Clear search" : "清除搜索"
                        )
                        Text(en ? "\(filteredApps.count) entries" : "\(filteredApps.count) 个条目")
                            .font(.caption)
                            .foregroundStyle(NexaPalette.muted)
                        ForEach(filteredApps) { app in
                            NexaCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(app.displayName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(app.bundleID)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(NexaPalette.muted)
                                        .textSelection(.enabled)
                                    NavigationLink {
                                        // The original Nexa explorer will ask for
                                        // explicit authorization again. It never
                                        // accepts a catalog's consent implicitly.
                                        NexaWQExplorerView(initialPath: app.id)
                                    } label: {
                                        Label(en ? "Open read-only folder explorer"
                                                 : "进入只读目录浏览",
                                              systemImage: "folder.badge.gearshape")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(!agreed || !NexaContainerAccess.ready)
                                }
                            }
                        }
                    }
                    Text(en
                        ? "Metadata list is not the original WQApps backup/restore manager. A LaunchServices record does not grant access to an App's files."
                        : "此页面并非原版 WQApps 备份／恢复管理器。LaunchServices 记录不等于获得了访问 App 文件的权限。")
                        .font(.caption2)
                        .foregroundStyle(NexaPalette.muted)
                }
                .padding(20)
            }
        }
        .navigationTitle(en ? "App catalog" : "应用目录")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: agreed) { _, allowed in
            if !allowed {
                apps = []
                searchText = ""
                message = nil
            }
        }
    }

    private func loadCatalog() {
        guard agreed, NexaContainerAccess.ready, !loading else { return }
        loading = true
        apps = []
        message = nil
        Task.detached(priority: .userInitiated) {
            // All original source calls happen away from the SwiftUI main
            // actor. They may consult the daemon LaunchServices cache.
            wq_load_display_names()
            let discovered = wq_ls_container_paths(nil)
            var rows: [AppRecord] = []
            var seen: Set<String> = []
            for path in (discovered ?? []).prefix(600) {
                guard !seen.contains(path),
                      let bundleID = wq_bundle_id_for_container(path),
                      WQAppsSupportBundleIDValid(bundleID) else { continue }
                seen.insert(path)
                let title = wq_display_name(bundleID) ?? bundleID
                rows.append(AppRecord(id: path, bundleID: bundleID,
                                      displayName: title))
            }
            let databaseFound = discovered != nil
            await MainActor.run {
                defer { loading = false }
                guard agreed && NexaContainerAccess.ready else {
                    apps = []
                    return
                }
                apps = rows.filter { NexaContainerAccess.valid($0.id) }.sorted {
                    let order = $0.displayName.localizedStandardCompare($1.displayName)
                    return order == .orderedSame ? $0.bundleID < $1.bundleID : order == .orderedAscending
                }
                if !databaseFound {
                    message = en
                        ? "The original LaunchServices cache could not be read. This is not evidence of access rights."
                        : "无法读取原版 LaunchServices 缓存，这不代表已经获得访问权限。"
                } else if apps.isEmpty {
                    message = en
                        ? "No matching authorized app entries were found."
                        : "没有找到符合条件的已识别 App 条目。"
                }
            }
        }
    }
}
