import SwiftUI
import Combine
import WatchConnectivity

@main
struct NexaWatchApp: App {
    @StateObject private var link = NexaWatchLink()
    @AppStorage("nexa.language") private var language = "zh"

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                NexaWatchDashboard()
            }
                .environmentObject(link)
                .environment(\.locale, Locale(identifier: language == "en" ? "en" : "zh-Hans"))
                .preferredColorScheme(.dark)
        }
    }
}

struct NexaWatchDashboard: View {
    @EnvironmentObject private var link: NexaWatchLink
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("nexa.language") private var language = "zh"
    @AppStorage("nexa.hermes.consent") private var hermesConsent = false

    private var en: Bool { language == "en" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundStyle(.mint)
                Text("Nexa")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(en ? "Explore Beyond Limits." : "探索无限可能。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                statusCard
                Button {
                    link.reactivate()
                } label: {
                    Label(en ? "Refresh link" : "刷新连接", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Button {
                    link.pingPhone()
                } label: {
                    Label(en ? "Test iPhone link" : "测试 iPhone 连接", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                Picker(en ? "Language" : "语言", selection: $language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .font(.footnote)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(en ? "HermesEnabler 2" : "HermesEnabler 2 · 实验功能")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 6) {
                        Label(en ? "Backup / uninstall warning" : "备份及卸载警告",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                        Text(en
                            ? "Upstream: restore the original MobileGestalt backup BEFORE uninstalling. Keep the same Bundle ID and Apple ID when updating. System changes may cause data loss. Nexa has not tested device rollback."
                            : "上游警告：卸载前务必先恢复原始 MobileGestalt 备份；更新须保持相同 Bundle ID 和 Apple ID。系统改动可能导致数据丢失；Nexa 尚未通过真机回滚测试。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if NexaHermesGate.ready {
                        Toggle(
                            en ? "I understand that system changes can cause data loss" :
                                 "我了解系统修改可能导致数据损坏",
                            isOn: $hermesConsent
                        )
                        .font(.caption)
                        if hermesConsent {
                            NavigationLink {
                                ContentView()
                                    .onAppear { WatchConnectivityManager.shared.activate() }
                                    .onDisappear { link.reactivate() }
                            } label: {
                                Label(en ? "Open upstream tools" : "进入上游功能",
                                      systemImage: "applewatch.watchface")
                            }
                        }
                    } else {
                        Text(en
                            ? "Requires a supported watchOS 27.0–27.2 build and a provisioned Watch App Group. No simulator access."
                            : "需要上游已报告支持的 watchOS 27.0–27.2 和实际签名的 Watch App Group；模拟器不开放。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(en ? "Nexa 0.0.1 · Watch companion" : "Nexa 0.0.1 · 手表配套端")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(en
                    ? "Connection diagnostics remain available. Experimental Hermes tools require a verified backup, supported watchOS and App Group signing."
                    : "连接诊断始终可用；Hermes 实验功能须先备份，并在支持的 watchOS 和有效 App Group 签名下使用。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
        }
        .onAppear { link.reactivate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { link.reactivate() }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(en ? "Phone connection" : "手机连接", systemImage: "iphone.gen3")
                .font(.caption.weight(.semibold))
            Text(link.isReachable
                 ? (en ? "Reachable" : "可连接")
                 : (en ? "Not reachable" : "暂不可连接"))
                .foregroundStyle(link.isReachable ? .mint : .orange)
            if let response = link.response {
                Text(response)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }
}

// Nexa only reads reachability and sends diagnostic pings. The ORIGINAL
// HermesEnabler WatchConnectivityManager stays the sole Watch delegate for
// original MobileGestalt backups, transfers and external restore candidates.
@MainActor
final class NexaWatchLink: NSObject, ObservableObject {
    @Published private(set) var isReachable = false
    @Published private(set) var response: String?

    override init() {
        super.init()
        reactivate()
    }

    func reactivate() {
        guard WCSession.isSupported() else {
            isReachable = false
            return
        }
        WatchConnectivityManager.shared.activate()
        refresh()
    }

    private func refresh() {
        isReachable = WCSession.isSupported() && WCSession.default.isReachable
    }

    func pingPhone() {
        refresh()
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            response = "iPhone unavailable"
            return
        }
        WCSession.default.sendMessage(
            ["event": "nexa.ping", "version": "0.0.1"],
            replyHandler: { [weak self] message in
                Task { @MainActor [weak self] in
                    self?.response = message["status"] as? String ?? "Connected"
                    self?.refresh()
                }
            },
            errorHandler: { [weak self] error in
                Task { @MainActor [weak self] in
                    self?.response = error.localizedDescription
                    self?.refresh()
                }
            }
        )
    }
}

// Optional Ping response implemented as a thin extension of the unchanged
// upstream Hermes WatchConnectivityManager. WCSession.default.delegate
// is never reassigned to NexaWatchLink, including while on the dashboard.
extension WatchConnectivityManager {
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message["event"] as? String == "nexa.ping" {
            replyHandler(["status": "Nexa Watch 0.0.1", "event": "nexa.pong"])
        } else {
            replyHandler(["status": "Unsupported message"])
        }
    }
}
