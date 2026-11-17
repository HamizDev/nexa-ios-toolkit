import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var language: NexaLanguage
    @State private var importedCount = 0
    @State private var freeSpace: Int64 = 0
    @State private var showExplore = false

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            NexaBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    hero
                    overview
                    workspace
                    research
                    Text(language.t("home.notice"))
                        .font(.footnote)
                        .foregroundStyle(NexaPalette.muted)
                        .padding(.bottom, 22)
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: refresh)
        .navigationDestination(isPresented: $showExplore) { ModulesView() }
    }

    private var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.25, green: 0.21, blue: 0.46), NexaPalette.ink2], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .fill(NexaPalette.violet.opacity(0.40))
                .frame(width: 215, height: 215)
                .blur(radius: 70)
                .offset(x: 190, y: -100)
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.title2).foregroundStyle(NexaPalette.mint)
                    Text(language.t("hero.eyebrow"))
                        .font(.caption.weight(.bold)).tracking(2)
                        .foregroundStyle(.white.opacity(0.84))
                    Spacer()
                    NexaTag(text: "v0.0.1", color: NexaPalette.mint)
                }
                Spacer(minLength: 12)
                Text(language.t("hero.title"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(language.t("hero.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.70))
                    .fixedSize(horizontal: false, vertical: true)
                Button { showExplore = true } label: {
                    HStack(spacing: 8) {
                        Text(language.t("hero.button")).fontWeight(.semibold)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)
                Text(language.t("hero.note"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.47))
            }
            .padding(25)
        }
        .frame(minHeight: 285)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay { RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.12)) }
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(language.t("home.overview")).font(.title3.weight(.semibold))
            HStack(spacing: 12) {
                metric(symbol: "iphone.gen3", value: "iOS \(UIDevice.current.systemVersion)", title: language.t("home.os"), tint: NexaPalette.violet)
                metric(symbol: "externaldrive", value: ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file), title: language.t("home.storage"), tint: NexaPalette.mint)
                metric(symbol: "folder", value: String(importedCount), title: language.t("home.files"), tint: NexaPalette.blue)
            }
        }
    }

    private func metric(symbol: String, value: String, title: String, tint: Color) -> some View {
        NexaCard {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(value).font(.footnote.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.caption2).foregroundStyle(NexaPalette.muted).lineLimit(1)
            }
        }
    }

    private var workspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.t("home.library")).font(.title3.weight(.semibold))
            LazyVGrid(columns: grid, spacing: 12) {
                shortcut(language.t("home.shortcut.files"), icon: "folder.fill", color: NexaPalette.blue, destination: AnyView(FilesView()))
                shortcut(language.t("home.shortcut.backup"), icon: "checkmark.shield.fill", color: NexaPalette.mint, destination: AnyView(BackupView()))
                shortcut(language.t("home.shortcut.device"), icon: "iphone.gen3", color: NexaPalette.violet, destination: AnyView(DeviceView()))
                shortcut(language.t("home.shortcut.watch"), icon: "applewatch", color: .orange, destination: AnyView(WatchView()))
            }
        }
    }

    private func shortcut(_ title: String, icon: String, color: Color, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            NexaCard {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: icon).font(.title2).foregroundStyle(color)
                        .frame(width: 40, height: 40)
                        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    HStack {
                        Text(title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(NexaPalette.muted)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var research: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language.t("home.section")).font(.title3.weight(.semibold))
            Text(language.t("home.section.subtitle"))
                .font(.footnote).foregroundStyle(NexaPalette.muted)
            ForEach(ModuleCatalog.highlighted) { module in
                NavigationLink(destination: ModuleDetailView(module: module)) {
                    ModuleRow(module: module)
                }.buttonStyle(.plain)
            }
        }
    }

    private func refresh() {
        importedCount = ((try? FileManager.default.contentsOfDirectory(at: AppPaths.importFolder, includingPropertiesForKeys: nil)) ?? []).count
        if let values = try? AppPaths.documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]) {
            freeSpace = values.volumeAvailableCapacityForImportantUsage ?? 0
        }
    }
}
