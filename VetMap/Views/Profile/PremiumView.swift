import SwiftUI
import StoreKit

struct PremiumView: View {
    @StateObject private var viewModel = PremiumViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                featureList
                planCards
                restoreButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.screenBackground)
        .task {
            await viewModel.loadProducts()
            await viewModel.checkEntitlement()
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
        VStack(spacing: 12) {
            Text("👑")
                .font(.system(size: 56))

            Text("VetMap Premium")
                .font(.largeTitle.weight(.bold))

            Text("解鎖完整功能，為毛孩搵到最好嘅照顧")
            Text("🎁 7日免費試用，隨時取消")
                .font(.subheadline)
                .foregroundStyle(AppTheme.warning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Premium 會員權益")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                featureRow("checkmark.shield.fill", "完整台灣及香港獸醫診所資料庫")
                featureRow("magnifyingglass.circle.fill", "無限量診所搜尋及篩選")
                featureRow("message.fill", "社群報價及評論完整存取")
                featureRow("eye.slash.fill", "無廣告瀏覽體驗")
                featureRow("star.fill", "每月獨家毛孩照護內容")
                featureRow("headphones.circle.fill", "優先客戶支援")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .appCard()
    }

    private func featureRow(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        VStack(spacing: 14) {
            Text("選擇方案")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .top, spacing: 12) {
                monthlyPlanCard
                yearlyPlanCard
            }
        }
    }

    private var monthlyPlanCard: some View {
        VStack(spacing: 12) {
            Text("月費計劃")
                .font(.headline)

            VStack(spacing: 2) {
                Text(viewModel.product(for: .monthly)?.displayPrice ?? "NT$80")
                    .font(.title.weight(.bold))
                Text("/ 月")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("HK$20")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Analytics.premiumPurchaseStarted("monthly")
                Task { await viewModel.purchase(.monthly) }
            } label: {
                Group {
                    if viewModel.isPurchasing && viewModel.selectedPlan == .monthly {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("訂閱")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .foregroundStyle(.white)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(viewModel.isPurchasing)
            .buttonStyle(.plain)
        }
        .padding(16)
        .appCard()
    }

    private var yearlyPlanCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("年費計劃")
                    .font(.headline)

                Text("省 17%")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.warning, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }

            VStack(spacing: 2) {
                Text(viewModel.product(for: .yearly)?.displayPrice ?? "NT$1,000")
                    .font(.title.weight(.bold))
                Text("/ 年")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("HK$250")
                .font(.caption)
                .foregroundStyle(.secondary)

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
            }
            .foregroundStyle(.white)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .disabled(viewModel.isPurchasing)
            .buttonStyle(.plain)
        }
        .padding(16)
        .appCard()
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
                }
            }
            .foregroundStyle(AppTheme.primary)
        }
        .disabled(viewModel.isPurchasing)
    }
}

#Preview {
    NavigationStack {
        PremiumView()
    }
}
