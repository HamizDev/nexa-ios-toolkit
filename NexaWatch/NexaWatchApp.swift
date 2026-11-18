import SwiftUI
import Combine
import WatchConnectivity

@main
struct NexaWatchApp: App {
    @StateObject private var link = NexaWatchLink()
    @AppStorage("nexa.language") private var language = "zh"

    var body: some Scene {
        WindowGroup {
            NexaWatchDashboard()
                .environmentObject(link)
                .environment(\.locale, Locale(identifier: language == "en" ? "en" : "zh-Hans"))
                .preferredColorScheme(.dark)
        }
    }
}

struct NexaWatchDashboard: View {
    @EnvironmentObject private var link: NexaWatchLink
    @AppStorage("nexa.language") private var language = "zh"

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
                    link.pingPhone()
                } label: {
                    Label(en ? "Test iPhone link" : "测试 iPhone 连接", systemImage: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(!link.isReachable)
                Picker(en ? "Language" : "语言", selection: $language) {
                    Text("中文").tag("zh")
                    Text("English").tag("en")
                }
                .font(.footnote)
                Text(en ? "Nexa 0.0.1 · Watch companion" : "Nexa 0.0.1 · 手表配套端")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(en
                    ? "This companion provides diagnostics. Hermes watch-face changes are not enabled."
                    : "当前配套端仅提供连接诊断，尚未启用 Hermes 表盘修改。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
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

@MainActor
final class NexaWatchLink: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var isReachable = false
    @Published private(set) var response: String?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        refresh()
    }

    private func refresh() {
        isReachable = WCSession.isSupported() && WCSession.default.isReachable
    }

    func pingPhone() {
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

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor [weak self] in
            self?.response = error?.localizedDescription
            self?.refresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        replyHandler(["status": "Nexa Watch 0.0.1", "event": "nexa.pong"])
        Task { @MainActor [weak self] in self?.refresh() }
    }
}
