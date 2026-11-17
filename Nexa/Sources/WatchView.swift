import SwiftUI
import WatchConnectivity

struct WatchView: View {
    @EnvironmentObject private var language: NexaLanguage

    @StateObject private var monitor = NexaWatchMonitor()

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("watch.title"), subtitle: language.t("watch.subtitle"))
                    NexaCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 48))
                                .foregroundStyle(NexaPalette.violet)
                            HStack {
                                Text(language.t("watch.paired"))
                                Spacer()
                                NexaTag(text: monitor.paired ? language.t("watch.yes") : language.t("watch.no"), color: monitor.paired ? NexaPalette.mint : NexaPalette.muted)
                            }
                            HStack {
                                Text(language.code == "en" ? "Watch session" : "手表会话")
                                Spacer()
                                Text(monitor.activationState).foregroundStyle(NexaPalette.muted)
                            }
                            .font(.caption)
                            HStack {
                                Text(language.code == "en" ? "Nexa watch app" : "Nexa 手表端")
                                Spacer()
                                Text(monitor.watchAppInstalled ? (language.code == "en" ? "Installed" : "已安装") : (language.code == "en" ? "Not installed" : "未安装"))
                                    .foregroundStyle(NexaPalette.muted)
                            }
                            .font(.caption)
                            Button(language.t("common.refresh")) { monitor.refresh() }
                                .font(.caption)
                            Button {
                                monitor.pingWatch()
                            } label: {
                                Label(language.code == "en" ? "Test Watch link" : "测试手表连接",
                                      systemImage: "arrow.left.arrow.right")
                            }
                            .disabled(!monitor.reachable)
                            if let pingResult = monitor.pingResult {
                                Text(pingResult).font(.caption).foregroundStyle(NexaPalette.muted)
                            }
                            Text(language.t("watch.none"))
                                .font(.footnote).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        Link(destination: URL(string: "https://github.com/pookjw/HermesEnabler")!) {
                            Label(language.t("watch.source"), systemImage: "arrow.up.right.square")
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(language.t("watch.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
