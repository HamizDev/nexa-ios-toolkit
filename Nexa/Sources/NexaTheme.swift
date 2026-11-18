import SwiftUI

enum NexaPalette {
    static let ink = Color(red: 0.045, green: 0.055, blue: 0.11)
    static let ink2 = Color(red: 0.075, green: 0.09, blue: 0.17)
    static let violet = Color(red: 0.61, green: 0.49, blue: 1.0)
    static let blue = Color(red: 0.36, green: 0.68, blue: 1.0)
    static let mint = Color(red: 0.46, green: 0.93, blue: 0.82)
    static let muted = Color(red: 0.66, green: 0.70, blue: 0.82)

    static let accent = LinearGradient(
        colors: [violet, blue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct NexaBackground: View {
    var body: some View {
        ZStack {
            NexaPalette.ink
            RadialGradient(colors: [NexaPalette.violet.opacity(0.16), .clear], center: .topTrailing, startRadius: 10, endRadius: 360)
            RadialGradient(colors: [NexaPalette.blue.opacity(0.10), .clear], center: .bottomLeading, startRadius: 10, endRadius: 340)
        }
        .ignoresSafeArea()
    }
}

struct NexaCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(reduceTransparency ? NexaPalette.ink2 : .white.opacity(0.075))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            )
    }
}

struct NexaHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(NexaPalette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

struct NexaTag: View {
    let text: String
    var color: Color = NexaPalette.blue
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.13), in: Capsule())
    }
}

struct NexaActionButton: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.white)
                .background(NexaPalette.accent, in: RoundedRectangle(cornerRadius: 15))
        }
        .buttonStyle(.plain)
    }
}
