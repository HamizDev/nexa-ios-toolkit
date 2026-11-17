import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var store = FilesStore()
    @State private var isImporterPresented = false

    var body: some View {
        List {
            Section {
                Label("仅管理你主动选择导入的文件，不会扫描其他 App 的私有容器。", systemImage: "lock.shield")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("已导入") {
                if store.entries.isEmpty {
                    ContentUnavailableView("还没有文件", systemImage: "folder", description: Text("点击右上角 + 从“文件”App 选择文件或文件夹"))
                } else {
                    ForEach(store.entries) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                .foregroundStyle(.indigo)
                            VStack(alignment: .leading) {
                                Text(entry.name).lineLimit(2)
                                Text(entry.isDirectory ? "文件夹" : "文件")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            ShareLink(item: entry.url) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
        }
        .navigationTitle("我的文件")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isImporterPresented = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("导入文件")
            }
        }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): store.importURLs(urls)
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .alert("文件操作提示", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("确定", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
