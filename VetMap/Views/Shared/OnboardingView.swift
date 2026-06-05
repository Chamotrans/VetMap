import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, subtitle: String)] = [
        ("pawprint.fill", "歡迎來到 VetMap", "搵到最可靠嘅獸醫診所"),
        ("map.fill", "地圖搜尋", "瀏覽附近診所、睇評價、比較價格"),
        ("star.fill", "分享經驗", "寫評價、分享報價、幫其他毛孩家長")
    ]

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    hasSeenOnboarding = true
                } label: {
                    Label("開始使用", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    private func pageView(_ page: (icon: String, title: String, subtitle: String)) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(AppTheme.primary)
                .padding(.bottom, 8)

            Text(page.title)
                .font(.title.weight(.bold))

            Text(page.subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
