import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject private var language: NexaLanguage
    @StateObject private var store = FilesStore()
    @State private var importSheet = false

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NexaHeader(title: language.t("files.title"), subtitle: language.t("files.subtitle"))
                    NexaCard {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(NexaPalette.mint)
                            Text(language.t("files.access"))
                                .font(.footnote)
                                .foregroundStyle(NexaPalette.muted)
                        }
                    }
                    NexaActionButton(title: language.t("files.import"), symbol: "plus") {
                        importSheet = true
                    }
                    if store.entries.isEmpty {
                        NexaCard {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 34))
                                    .foregroundStyle(NexaPalette.blue)
                                Text(language.t("files.empty")).font(.headline)
                                Text(language.t("files.empty.detail"))
                                    .font(.subheadline)
                                    .foregroundStyle(NexaPalette.muted)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    } else {
                        NexaCard {
                            VStack(spacing: 0) {
                                ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                                    HStack(spacing: 11) {
                                        NavigationLink(destination: entry.isDirectory ? AnyView(LocalFolderView(folder: entry.url)) : AnyView(FileInspectorView(file: entry.url))) {
                                            HStack(spacing: 11) {
                                                Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                                    .foregroundStyle(entry.isDirectory ? NexaPalette.violet : NexaPalette.blue)
                                                    .frame(width: 28)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(entry.name).font(.subheadline.weight(.medium)).lineLimit(2)
                                                    Text(language.t(entry.isDirectory ? "files.folder" : "files.file"))
                                                        .font(.caption).foregroundStyle(NexaPalette.muted)
                                                }
                                                Spacer(minLength: 0)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        ShareLink(item: entry.url) {
                                            Image(systemName: "square.and.arrow.up")
                                                .foregroundStyle(NexaPalette.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 10)
                                    .contextMenu {
                                        ShareLink(item: entry.url) { Label(language.t("common.share"), systemImage: "square.and.arrow.up") }
                                        Button(role: .destructive) { store.remove(entry) } label: { Label(language.t("files.delete"), systemImage: "trash") }
                                    }
                                    if index + 1 < store.entries.count { Divider().overlay(.white.opacity(0.07)) }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { importSheet = true } label: { Image(systemName: "plus") }
            }
        }
        .fileImporter(isPresented: $importSheet, allowedContentTypes: [.item, .folder], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): store.importURLs(urls)
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .alert(language.t("common.error"), isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button(language.t("common.confirm"), role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}
