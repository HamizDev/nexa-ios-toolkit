import SwiftUI
import WatchConnectivity

struct WatchView: View {
    @EnvironmentObject private var language: NexaLanguage

    private var paired: Bool {
        WCSession.isSupported() && WCSession.default.isPaired
    }

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
                                NexaTag(text: paired ? language.t("watch.yes") : language.t("watch.no"), color: paired ? NexaPalette.mint : NexaPalette.muted)
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
