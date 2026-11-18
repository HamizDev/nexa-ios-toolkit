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
    @State private var selectedTab: String = {
        #if DEBUG
        // UI screenshot smoke tests can open a specific tab without fragile
        // accessibility-coordinate automation. Release ignores this argument.
        if let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("--nexa-tab=")
        }) {
            let target = String(argument.dropFirst("--nexa-tab=".count))
            if ["home", "files", "backups", "explore", "settings"].contains(target) {
                return target
            }
        }
        #endif
        return "home"
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label(language.t("tab.home"), systemImage: "house.fill") }
                .tag("home")
            NavigationStack { FilesView() }
                .tabItem { Label(language.t("tab.files"), systemImage: "folder.fill") }
                .tag("files")
            NavigationStack { BackupView() }
                .tabItem { Label(language.t("tab.backups"), systemImage: "externaldrive.fill") }
                .tag("backups")
            NavigationStack { ModulesView() }
                .tabItem { Label(language.t("tab.explore"), systemImage: "square.grid.2x2.fill") }
                .tag("explore")
            NavigationStack { SettingsView() }
                .tabItem { Label(language.t("tab.settings"), systemImage: "slider.horizontal.3") }
                .tag("settings")
        }
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(NexaPalette.ink2, for: .tabBar)
        #if DEBUG
        .onAppear(perform: recordUITestTab)
        .onChange(of: selectedTab) { _, _ in recordUITestTab() }
        #endif
    }

    #if DEBUG
    private func recordUITestTab() {
        // A DEBUG-only handshake makes CI verify the selected tab, rather
        // than accepting five PNGs that all show the Home screen.
        guard ProcessInfo.processInfo.arguments.contains(where: {
            $0.hasPrefix("--nexa-tab=")
        }) else { return }
        let location = AppPaths.documents
            .appendingPathComponent(".nexa-ui-smoke-current-tab")
        try? FileManager.default.createDirectory(
            at: AppPaths.documents, withIntermediateDirectories: true
        )
        try? selectedTab.write(to: location, atomically: true, encoding: .utf8)
    }
    #endif
}
