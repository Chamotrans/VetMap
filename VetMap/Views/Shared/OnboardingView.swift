import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var iconBounce = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var buttonVisible = false

    private let pages: [(icon: String, accentIcon: String, title: String, subtitle: String, tint: Color)] = [
        (
            icon: "heart.fill",
            accentIcon: "pawprint.fill",
            title: "歡迎來到 VetMap",
            subtitle: "搵到最可靠嘅獸醫診所\n為毛孩揀最好嘅照顧",
            tint: Color(red: 0.91, green: 0.66, blue: 0.22) // warm amber
        ),
        (
            icon: "mappin.and.ellipse",
            accentIcon: "magnifyingglass",
            title: "地圖搜尋",
            subtitle: "瀏覽附近診所、睇真實評價\n比較費用、一鍵導航",
            tint: Color(red: 0.24, green: 0.48, blue: 0.36) // sage green
        ),
        (
            icon: "star.fill",
            accentIcon: "bubble.left.fill",
            title: "社群分享",
            subtitle: "寫評價、分享報價\n幫其他毛孩家長做明智選擇",
            tint: Color(red: 0.91, green: 0.66, blue: 0.22) // warm amber
        )
    ]

    // MARK: - Warm palette
    private let warmCream = Color(red: 0.98, green: 0.96, blue: 0.92)
    private let warmAmber = Color(red: 0.91, green: 0.66, blue: 0.22)
    private let sageGreen = Color(red: 0.24, green: 0.48, blue: 0.36)

    var body: some View {
        ZStack {
            // 暖色奶油背景 + 微粒紋理
            warmCream.ignoresSafeArea()

            // Subtle pawprint pattern overlay
            GeometryReader { proxy in
                Canvas { context, size in
                    guard let pawprint = context.resolveSymbol(id: "pawprint") else { return }
                    let spacing: CGFloat = 60
                    var x: CGFloat = -20
                    var y: CGFloat = -20
                    while y < size.height + 40 {
                        x = -20 + (Int(y / spacing) % 2 == 0 ? 0 : spacing / 2)
                        while x < size.width + 40 {
                            var pawContext = context
                            pawContext.opacity = 0.04
                            pawContext.draw(pawprint, at: CGPoint(x: x, y: y))
                            x += spacing
                        }
                        y += spacing * 0.85
                    }
                } symbols: {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.brown)
                        .tag("pawprint")
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                // 頁面內容
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        pageView(pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    resetAnimations()
                }

                // 自訂指示器
                customPageIndicator
                    .padding(.top, 8)

                Spacer()

                // CTA 按鈕 — 永遠 render，用 opacity/offset 控制進場
                Button {
                    hasSeenOnboarding = true
                } label: {
                    HStack(spacing: 8) {
                        Text("開始使用")
                            .font(.headline.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [warmAmber, warmAmber.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .shadow(color: warmAmber.opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 16)

                // 服務條款 + 私隱政策
                legalFooter
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                    .opacity(buttonVisible ? 1 : 0)
            }
        }
        .onAppear {
            triggerAnimations()
        }
    }

    // MARK: - 單頁內容

    private func pageView(_ page: (icon: String, accentIcon: String, title: String, subtitle: String, tint: Color)) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // 插畫：雙層 SF Symbols 組合
            ZStack {
                // 大背景圈
                Circle()
                    .fill(page.tint.opacity(0.08))
                    .frame(width: 180, height: 180)

                Circle()
                    .stroke(page.tint.opacity(0.2), lineWidth: 2)
                    .frame(width: 160, height: 160)

                // 主 icon
                Image(systemName: page.icon)
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(page.tint)
                    .symbolEffect(.bounce, options: .speed(0.6), value: iconBounce)
                    .offset(x: -16, y: -8)

                // 輔助小 icon
                Image(systemName: page.accentIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(page.tint.opacity(0.7))
                    .symbolEffect(.bounce, options: .speed(0.4), value: iconBounce)
                    .offset(x: 28, y: 22)
            }
            .padding(.bottom, 48)

            // 標題 — 永遠 render，用 opacity/offset 控制進場（避免 TabView 分頁內條件插入失效）
            Text(page.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color(red: 0.22, green: 0.18, blue: 0.12))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 12)

            // 副標題
            Text(page.subtitle)
                .font(.title3)
                .foregroundStyle(Color(red: 0.42, green: 0.38, blue: 0.32))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
                .opacity(subtitleVisible ? 1 : 0)
                .offset(y: subtitleVisible ? 0 : 12)

            Spacer()
            Spacer()
        }
    }

    // MARK: - 服務條款 + 私隱政策

    private var legalFooter: some View {
        VStack(spacing: 2) {
            Text("繼續即代表你同意我們的")
                .font(.caption2)
                .foregroundStyle(Color(red: 0.5, green: 0.46, blue: 0.40))

            HStack(spacing: 4) {
                Link("服務條款", destination: URL(string: "https://vetmap-app.web.app/tos")!)
                    .font(.caption2.weight(.semibold))
                    .tint(warmAmber)

                Text("與")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.5, green: 0.46, blue: 0.40))

                Link("私隱政策", destination: URL(string: "https://vetmap-app.web.app")!)
                    .font(.caption2.weight(.semibold))
                    .tint(warmAmber)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 自訂頁面指示器

    private var customPageIndicator: some View {
        HStack(spacing: 10) {
            ForEach(pages.indices, id: \.self) { index in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                        currentPage = index
                    }
                } label: {
                    ZStack {
                        if currentPage == index {
                            // 當前頁：藥丸形 + 填滿色
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(warmAmber)
                                .frame(width: 24, height: 8)
                                .shadow(color: warmAmber.opacity(0.4), radius: 4, y: 2)
                        } else {
                            // 非當前頁：小圓點
                            Circle()
                                .fill(Color.brown.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel("頁面 \(currentPage + 1) / \(pages.count)")
    }

    // MARK: - 動畫控制

    private func triggerAnimations() {
        iconBounce = true

        withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
            titleVisible = true
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.15)) {
            subtitleVisible = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.35)) {
            buttonVisible = true
        }
    }

    private func resetAnimations() {
        iconBounce = false
        titleVisible = false
        subtitleVisible = false
        buttonVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            triggerAnimations()
        }
    }
}

#Preview {
    OnboardingView()
}
