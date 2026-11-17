import SwiftUI

struct HomeView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.indigo)
                    Text("Nexa")
                        .font(.largeTitle.bold())
                    Text("把文件、备份、设备诊断和 Apple Watch 研究整理到一个中文界面。")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Label("当前为基础工程；漏洞利用及第三方功能尚未合并。", systemImage: "info.circle")
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                Text("模块规划").font(.title3.bold())
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ModuleCatalog.modules) { module in
                        ModuleTile(module: module)
                    }
                }
                Text("项目来源与接入说明").font(.title3.bold())
                ForEach(ModuleCatalog.modules) { module in
                    VStack(alignment: .leading, spacing: 6) {
                        Link(destination: module.repository) {
                            HStack {
                                Text(module.title).font(.headline)
                                Image(systemName: "arrow.up.right.square")
                            }
                        }
                        Text(module.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Nexa")
    }
}
