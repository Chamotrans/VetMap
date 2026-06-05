import SwiftUI

struct LoadingOverlay: View {
    var message: String = "載入中…"

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

struct ShimmerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            shimmerBlock(width: 140, height: 16)
            shimmerBlock(width: .infinity, height: 14)

            HStack(spacing: 8) {
                shimmerBlock(width: 72, height: 28)
                shimmerBlock(width: 88, height: 28)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.surface,
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
    }

    private func shimmerBlock(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.18))
            .frame(maxWidth: width == .infinity ? .infinity : width, minHeight: height)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
            .shimmering()
    }
}

struct ShimmerRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
                .shimmering()

            VStack(alignment: .leading, spacing: 6) {
                Rectangle()
                    .fill(Color.gray.opacity(0.18))
                    .frame(width: 160, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
                    .shimmering()

                Rectangle()
                    .fill(Color.gray.opacity(0.18))
                    .frame(width: 240, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
                    .shimmering()
            }

            Spacer()

            Rectangle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 40, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous))
                .shimmering()
        }
        .padding(14)
        .appCard()
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.35), location: 0.35),
                            .init(color: .white.opacity(0.55), location: 0.5),
                            .init(color: .white.opacity(0.35), location: 0.65),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .scaleEffect(x: 1.6, y: 1, anchor: .center)
                    .offset(x: phase * geometry.size.width)
                    .mask(content)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    VStack(spacing: 20) {
        ZStack {
            Color.teal
            LoadingOverlay(message: "正在載入診所資料…")
        }
        .frame(height: 300)
        .clipShape(RoundedRectangle(cornerRadius: 16))

        ShimmerCard()

        ShimmerRow()
    }
    .padding()
    .background(AppTheme.screenBackground)
}
