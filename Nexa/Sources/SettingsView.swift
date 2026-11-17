import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var language: NexaLanguage

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    NexaHeader(title: language.t("settings.title"), subtitle: language.t("settings.subtitle"))
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(language.t("settings.language"), systemImage: "globe")
                                .font(.headline)
                            Picker(language.t("settings.language"), selection: $language.code) {
                                Text("简体中文").tag("zh")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.segmented)
                            Text(language.t("settings.langhint"))
                                .font(.caption).foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(language.t("settings.privacy"), systemImage: "lock.shield.fill")
                                .font(.headline)
                            Text(language.t("settings.privacy.detail"))
                                .font(.subheadline)
                                .foregroundStyle(NexaPalette.muted)
                            Label(language.t("device.mode"), systemImage: "checkmark.shield")
                                .font(.caption).foregroundStyle(NexaPalette.mint)
                        }
                    }
                    NexaCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(language.t("settings.about"), systemImage: "info.circle")
                                .font(.headline)
                            Text("Nexa").font(.title2.weight(.bold))
                            Text(language.t("settings.build"))
                                .foregroundStyle(NexaPalette.muted)
                            Link(destination: URL(string: "https://github.com/HamizDev/nexa-ios-toolkit")!) {
                                Label(language.t("settings.source"), systemImage: "arrow.up.right.square")
                            }
                            Link(destination: URL(string: "https://github.com/HamizDev/nexa-ios-toolkit/blob/main/Documentation/UPSTREAM_SOURCES.md")!) {
                                Label(language.t("settings.upstream"), systemImage: "scroll")
                            }
                        }
                    }
                    Text(language.t("settings.disclaimer"))
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                        .padding(.bottom, 20)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
