import SwiftUI

@main
struct NexaApp: App {
    var body: some Scene {
        WindowGroup {
            ToolboxRootView()
                .tint(.indigo)
        }
    }
}

struct ToolboxRootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("首页", systemImage: "square.grid.2x2.fill") }
            NavigationStack { FilesView() }
                .tabItem { Label("文件", systemImage: "folder.fill") }
            NavigationStack { BackupView() }
                .tabItem { Label("备份", systemImage: "externaldrive.fill") }
            NavigationStack { DeviceView() }
                .tabItem { Label("设备", systemImage: "iphone.gen3") }
            NavigationStack { WatchView() }
                .tabItem { Label("手表", systemImage: "applewatch") }
        }
    }
}
