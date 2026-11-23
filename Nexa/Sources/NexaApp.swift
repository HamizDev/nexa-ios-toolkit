import SwiftUI

@main
struct NexaApp: App {
    @StateObject private var language = NexaLanguage()
    // The original Hermes iPhone WCSession delegate lives for the entire App.
    @StateObject private var hermesCompanion = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            NexaRootView()
                .environmentObject(language)
                .environmentObject(hermesCompanion)
                .preferredColorScheme(.dark)
                .tint(NexaPalette.violet)
        }
    }
}

struct NexaRootView: View {
    @EnvironmentObject private var language: NexaLanguage
    #if DEBUG
    @EnvironmentObject private var hermesCompanion: WatchConnectivityManager
    @State private var showWatchUISmoke = ProcessInfo.processInfo.arguments.contains("--nexa-watch-view")
    @State private var showOriginalHexUISmoke: NexaWQHexSelection?
    @State private var showOriginalPlistUISmoke: NexaWQPlistSelection?
    #endif
    @AppStorage("nexa.safety.disclaimer.read.0.0.1") private var hasReadSafety = false
    @State private var showFirstLaunchSafety = false
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
        .onAppear {
            if !hasReadSafety {
                #if DEBUG
                // UI screenshot harness opens individual tabs without covering
                // them with the first-run disclosure. Normal Debug launches
                // and every Release launch still present the disclosure.
                let isScreenshotHarness = ProcessInfo.processInfo.arguments.contains {
                    $0.hasPrefix("--nexa-tab=") || $0 == "--nexa-watch-view" ||
                    $0 == "--nexa-wqhex-smoke" || $0 == "--nexa-wqplist-smoke"
                }
                if !isScreenshotHarness { showFirstLaunchSafety = true }
                #else
                showFirstLaunchSafety = true
                #endif
            }
        }
        .sheet(isPresented: $showFirstLaunchSafety) {
            NavigationStack {
                NexaDisclaimerView(requiresAcknowledgment: true)
            }
            .environmentObject(language)
        }
        #if DEBUG
        .sheet(isPresented: $showWatchUISmoke) {
            NavigationStack { WatchView() }
                .onAppear(perform: recordWatchViewUITest)
        }
        .sheet(item: $showOriginalHexUISmoke) { selection in
            NexaWQOriginalHexView(file: selection.file)
                .onAppear { recordWQNativeUITest("hex") }
        }
        .sheet(item: $showOriginalPlistUISmoke) { selection in
            NexaWQOriginalPlistView(file: selection.file)
                .onAppear { recordWQNativeUITest("plist") }
        }
        .onAppear {
            recordUITestTab()
            if ProcessInfo.processInfo.arguments.contains("--nexa-hermes-fixture") {
                hermesCompanion.nexaRunSyntheticBackupFixture()
            }
            prepareWQNativeUITestIfNeeded()
        }
        .onChange(of: selectedTab) { _, _ in recordUITestTab() }
        #endif
    }

    #if DEBUG
    /// Synthetic import-owned fixtures only. Test arguments are ignored by
    /// Release, and no external container or privileged write is touched.
    private func prepareWQNativeUITestIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        let kind: String
        if arguments.contains("--nexa-wqhex-smoke") {
            kind = "hex"
        } else if arguments.contains("--nexa-wqplist-smoke") {
            kind = "plist"
        } else {
            return
        }
        let marker = AppPaths.documents.appendingPathComponent(".nexa-wq-native-ui-result")
        try? FileManager.default.removeItem(at: marker)
        do {
            try FileManager.default.createDirectory(
                at: AppPaths.importFolder, withIntermediateDirectories: true
            )
            let filename = "WQOriginal-" + UUID().uuidString
                + (kind == "plist" ? ".plist" : ".bin")
            let file = AppPaths.importFolder.appendingPathComponent(filename)
            if kind == "hex" {
                try Data((0..<256).map { UInt8($0) }).write(to: file, options: .atomic)
            } else {
                let value: [String: Any] = [
                    "Sample": "Nexa imported-file original viewer",
                    "Count": 3,
                    "Flags": ["ReadOnly": true, "Source": "Original WQFiles"]
                ]
                let contents = try PropertyListSerialization.data(
                    fromPropertyList: value, format: .binary, options: 0
                )
                try contents.write(to: file, options: .atomic)
            }
            let approved = try NexaLocalFiles.validatedImportedRegularFile(file)
            if kind == "hex" {
                showOriginalHexUISmoke = NexaWQHexSelection(file: approved)
            } else {
                showOriginalPlistUISmoke = NexaWQPlistSelection(file: approved)
            }
        } catch {
            try? ("FAIL: " + error.localizedDescription).write(
                to: marker, atomically: true, encoding: .utf8
            )
        }
    }

    private func recordWQNativeUITest(_ kind: String) {
        let marker = AppPaths.documents.appendingPathComponent(".nexa-wq-native-ui-result")
        try? ("PASS: WQFiles native " + kind).write(
            to: marker, atomically: true, encoding: .utf8
        )
    }

    private func recordWatchViewUITest() {
        guard ProcessInfo.processInfo.arguments.contains("--nexa-watch-view") else { return }
        let marker = AppPaths.documents.appendingPathComponent(".nexa-watch-ui-current-view")
        try? "watch-companion".write(to: marker, atomically: true, encoding: .utf8)
    }

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
