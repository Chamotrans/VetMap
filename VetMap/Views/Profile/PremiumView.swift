import SwiftUI
import StoreKit

struct PremiumView: View {
    @State private var viewModel = PremiumViewModel()
    @State private var featureVisibility: [Bool] = Array(repeating: false, count: 6)
    @State private var crownBounce = false
    @State private var cardsVisible = false

    // MARK: - 調色板
    private let warmAmber = Color(red: 0.91, green: 0.66, blue: 0.22)
    private let darkCharcoal = Color(red: 0.12, green: 0.10, blue: 0.08)
    private let creamWhite = Color(red: 0.98, green: 0.96, blue: 0.93)

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                featureList
                planCards

                if cardsVisible {
                    restoreButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProducts()
            await viewModel.checkEntitlement()
            triggerEntranceAnimations()
        }
        .alert("購買成功", isPresented: $viewModel.purchaseSuccess) {
            Button("完成", role: .cancel) {}
        } message: {
            Text("你已成功升級為 Premium 會員，盡情使用所有功能吧！")
        }
        .alert("購買失敗", isPresented: .init(
            get: { viewModel.purchaseError != nil },
            set: { if !$0 { viewModel.purchaseError = nil } }
        )) {
            Button("確定", role: .cancel) { viewModel.purchaseError = nil }
        } message: {
            Text(viewModel.purchaseError ?? "")
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // 皇冠 icon - 替代 emoji
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [warmAmber, warmAmber.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: warmAmber.opacity(0.5), radius: 16, y: 8)

                Image(systemName: "crown.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .speed(0.6), value: crownBounce)
            }
            .padding(.top, 20)

            Text("VetMap Premium")
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(.white)

            Text("解鎖完整功能，為毛孩搵到最好嘅照顧")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            // 免費試用徽章
            HStack(spacing: 6) {
                Image(systemName: "gift.fill")
                    .font(.caption2.weight(.bold))
                Text("7日免費試用 · 隨時取消")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(darkCharcoal)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                warmAmber,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .shadow(color: warmAmber.opacity(0.4), radius: 8, y: 4)
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium 會員權益")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(features.indices, id: \.self) { index in
                    let (icon, text) = features[index]
                    HStack(spacing: 14) {
                        // 琥珀色圓形 icon
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(warmAmber)
                            .frame(width: 40, height: 40)
                            .background(
                                warmAmber.opacity(0.1),
                                in: Circle()
                            )

                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .opacity(featureVisibility.indices.contains(index) && featureVisibility[index] ? 1 : 0)
                    .offset(x: featureVisibility.indices.contains(index) && featureVisibility[index] ? 0 : -30)

                    if index < features.count - 1 {
                        Divider()
                            .padding(.leading, 54)
                    }
                }
            }
            .padding(16)
            .background(
                creamWhite,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.brown.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private let features: [(icon: String, text: String)] = [
        ("checkmark.shield.fill", "香港獸醫診所地圖與社群"),
        ("magnifyingglass.circle.fill", "無限量診所搜尋及篩選"),
        ("message.fill", "社群報價及評論完整存取"),
        ("eye.slash.fill", "無廣告瀏覽體驗"),
        ("star.fill", "每月獨家毛孩照護內容"),
        ("headphones.circle.fill", "優先客戶支援")
    ]

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 14) {
            Text("選擇方案")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)

            HStack(alignment: .top, spacing: 12) {
                monthlyPlanCard
                yearlyPlanCard
            }
            .opacity(cardsVisible ? 1 : 0)
            .offset(y: cardsVisible ? 0 : 30)
        }
    }

    // MARK: 月費卡
    private var monthlyPlanCard: some View {
        VStack(spacing: 14) {
            Text("月費計劃")
                .font(.headline.weight(.semibold))

            VStack(spacing: 2) {
                Text(viewModel.product(for: .monthly)?.displayPrice ?? "NT$80")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                    .foregroundStyle(.primary)

                Text("/ 月")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Analytics.premiumPurchaseStarted("monthly")
                Task { await viewModel.purchase(.monthly) }
            } label: {
                Group {
                    if viewModel.isPurchasing && viewModel.selectedPlan == .monthly {
                        ProgressView()
                            .tint(warmAmber)
                    } else {
                        Text("訂閱")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(warmAmber)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 12))
            .tint(warmAmber)
            .disabled(viewModel.isPurchasing)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: 年費卡（推薦）
    private var yearlyPlanCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Text("年費計劃")
                    .font(.headline.weight(.semibold))

                Text("最受歡迎")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(warmAmber, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            VStack(spacing: 2) {
                Text(viewModel.product(for: .yearly)?.displayPrice ?? "NT$1,000")
                    .font(.system(.title, design: .rounded).weight(.heavy))

                Text("/ 年")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                Text("省 17%")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(warmAmber)

            Button {
                Analytics.premiumPurchaseStarted("yearly")
                Task { await viewModel.purchase(.yearly) }
            } label: {
                Group {
                    if viewModel.isPurchasing && viewModel.selectedPlan == .yearly {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("訂閱")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [warmAmber, warmAmber.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: warmAmber.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPurchasing)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(warmAmber.opacity(0.45), lineWidth: 1.5)
        )
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await viewModel.restore() }
        } label: {
            Group {
                if viewModel.isPurchasing && viewModel.selectedPlan == nil {
                    ProgressView()
                } else {
                    Text("恢復購買")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(viewModel.isPurchasing)
    }

    // MARK: - Animations

    private func triggerEntranceAnimations() {
        // 皇冠彈出
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.1)) {
            crownBounce = true
        }

        // Feature 逐行動畫
        for index in features.indices {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.3 + Double(index) * 0.08)) {
                featureVisibility[index] = true
            }
        }

        // 方案卡片淡入
        let cardDelay = 0.3 + Double(features.count) * 0.08 + 0.2
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(cardDelay)) {
            cardsVisible = true
        }
    }
}

#Preview {
    NavigationStack {
        PremiumView()
    }
}
