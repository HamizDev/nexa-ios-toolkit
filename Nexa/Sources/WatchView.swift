import SwiftUI
import WatchConnectivity

struct WatchView: View {
    @EnvironmentObject private var language: NexaLanguage
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var monitor = NexaWatchMonitor.shared

    private var en: Bool { language.code == "en" }

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("watch.title"), subtitle: language.t("watch.subtitle"))
                    NexaCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 48))
                                .foregroundStyle(NexaPalette.violet)
                            Text(monitor.status.connection.title(language.code))
                                .font(.title3.weight(.semibold))
                            NexaTag(text: NexaRisk.readOnly.title(language.code), color: NexaPalette.blue)
                            Text(NexaRisk.readOnly.detail(language.code))
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            if let error = monitor.activationError {
                                Text(error).font(.footnote).foregroundStyle(.orange)
                            }
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            info(en ? "Session" : "会话状态", monitor.status.activation.title(language.code))
                            info(language.t("watch.paired"), value(monitor.status.paired, yes: en ? "Paired" : "已配对", no: en ? "Not paired" : "未配对"))
                            info(en ? "Nexa companion" : "Nexa 手表端", value(monitor.status.installed, yes: en ? "Installed" : "已安装", no: en ? "Not installed" : "未安装"))
                            info(en ? "Reachability" : "即时可达性", value(monitor.status.reachable, yes: en ? "Reachable" : "可达", no: en ? "Not reachable" : "不可达"))
                            if let date = monitor.updatedAt {
                                info(en ? "Last update" : "最近更新", date.formatted(date: .omitted, time: .standard))
                            }
                            Button { monitor.refresh(retry: true) } label: {
                                Label(language.t("common.refresh"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(monitor.status.activation == .unavailable)
                            Text(en ? "Unknown fields are not interpreted as failures. Reachability may change as the companion moves to the background." :
                                 "未知状态不代表连接失败。配套 App 进入后台时，即时可达性也可能改变。")
                                .font(.caption).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(en ? "Integration boundary" : "接入边界", systemImage: "info.circle").font(.headline)
                            Text(language.t("watch.none"))
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                            Link(destination: URL(string: "https://github.com/pookjw/HermesEnabler")!) {
                                Label(language.t("watch.source"), systemImage: "arrow.up.right.square")
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(language.t("watch.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { monitor.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { monitor.refresh() }
        }
    }

    private func value(_ value: Bool?, yes: String, no: String) -> String {
        guard let value else { return en ? "Unknown / not applicable" : "未知或不适用" }
        return value ? yes : no
    }

    private func info(_ title: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                Text(title).foregroundStyle(NexaPalette.muted)
                Spacer(minLength: 12)
                Text(value).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(NexaPalette.muted)
                Text(value)
            }
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
