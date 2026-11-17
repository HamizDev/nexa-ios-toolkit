import SwiftUI
import Foundation

struct LocalFolderView: View {
    @EnvironmentObject private var language: NexaLanguage
    let folder: URL
    @State private var children: [URL] = []

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(children, id: \.path) { url in
                        NavigationLink(destination: isFolder(url) ? AnyView(LocalFolderView(folder: url)) : AnyView(FileInspectorView(file: url))) {
                            NexaCard {
                                HStack {
                                    Image(systemName: isFolder(url) ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(NexaPalette.blue)
                                    Text(url.lastPathComponent)
                                        .font(.subheadline)
                                        .lineLimit(2)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(NexaPalette.muted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(folder.lastPathComponent)
        .onAppear {
            children = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isSymbolicLinkKey])) ?? [])
                .filter { (try? $0.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) != true }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        }
    }

    private func isFolder(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
}

struct FileInspectorView: View {
    @EnvironmentObject private var language: NexaLanguage
    let file: URL
    @State private var preview = Data()
    @State private var showHex = true
    @State private var validation: String?
    @State private var readError: String?

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    NexaHeader(title: language.t("files.inspector"), subtitle: file.lastPathComponent)
                    NexaCard {
                        HStack {
                            Image(systemName: "doc.zipper").foregroundStyle(NexaPalette.blue)
                            Text(language.t("files.size")).foregroundStyle(NexaPalette.muted)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        }
                    }
                    Picker("", selection: $showHex) {
                        Text(language.t("files.hex")).tag(true)
                        Text(language.t("files.text")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    NexaCard {
                        if let readError {
                            Text(readError).foregroundStyle(.red)
                        } else if showHex {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(preview.map { String(format: "%02X", $0) }.joined(separator: " "))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(NexaPalette.mint)
                                    .textSelection(.enabled)
                                Text(language.t("files.truncated"))
                                    .font(.caption2).foregroundStyle(NexaPalette.muted)
                                Button {
                                    // Validate the bytes through WQFiles' vendored WQCore parser.
                                    let encoded = preview.map { String(format: "%02X", $0) }.joined(separator: " ")
                                    if let parsed = WQParseHexExactly(encoded, preview.count) {
                                        validation = (parsed as Data) == preview
                                            ? language.t("files.hex.ok")
                                            : language.t("files.hex.fail")
                                    } else {
                                        validation = language.t("files.hex.fail")
                                    }
                                } label: {
                                    Label(language.t("files.hex.check"), systemImage: "checkmark.shield")
                                }
                                if let validation {
                                    Text(validation).font(.footnote).foregroundStyle(NexaPalette.muted)
                                }
                            }
                        } else {
                            Text(String(data: preview, encoding: .utf8) ?? language.t("files.no.preview"))
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                    ShareLink(item: file) {
                        Label(language.t("files.export"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
        }
        .navigationTitle(file.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: read)
    }

    private var size: Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: file.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func read() {
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            preview = try handle.read(upToCount: 256) ?? Data()
        } catch { readError = error.localizedDescription }
    }
}
