import SwiftUI

@main
struct NexaApp: App {
    @StateObject private var language = NexaLanguage()

    var body: some Scene {
        WindowGroup {
            NexaRootView()
                .environmentObject(language)
                .preferredColorScheme(.dark)
                .tint(NexaPalette.violet)
        }
    }
}

struct NexaRootView: View {
    @EnvironmentObject private var language: NexaLanguage

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label(language.t("tab.home"), systemImage: "house.fill") }
            NavigationStack { FilesView() }
                .tabItem { Label(language.t("tab.files"), systemImage: "folder.fill") }
            NavigationStack { BackupView() }
                .tabItem { Label(language.t("tab.backups"), systemImage: "externaldrive.fill") }
            NavigationStack { ModulesView() }
                .tabItem { Label(language.t("tab.explore"), systemImage: "square.grid.2x2.fill") }
            NavigationStack { SettingsView() }
                .tabItem { Label(language.t("tab.settings"), systemImage: "slider.horizontal.3") }
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(NexaPalette.ink2, for: .tabBar)
    }
}
