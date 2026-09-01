import SwiftUI

struct SupportDeveloperView: View {
    @State private var viewModel = SupportDeveloperViewModel()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("請開發團隊飲杯嘢", systemImage: "cup.and.saucer.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.primary)

                    Text("一次性支持 VetMap 核實香港診所資料、更新營業時間同持續維護地圖。")
                    Text("這不是訂閱，沒有自動續期，亦不會解鎖永久會員資格。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            Section("一次性支持") {
                if viewModel.isLoading {
                    HStack { ProgressView(); Text("正在載入支持選項…") }
                } else {
                    ForEach(viewModel.supportOptions) { option in
                        Button {
                            Task { await viewModel.purchase(productID: option.id) }
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title)
                                        .font(.headline)
                                    Text(option.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 12)
                                if viewModel.purchasingProductID == option.id {
                                    ProgressView()
                                } else if let price = option.displayPrice {
                                    Text(price)
                                        .font(.headline)
                                        .monospacedDigit()
                                } else {
                                    Text("未能載入")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(viewModel.isPurchasing || option.displayPrice == nil)
                        .accessibilityLabel("\(option.title)，\(option.displayPrice ?? "暫時未能載入")")
                        .accessibilityHint("一次性支持，並非訂閱或自動續期")
                    }

                    if viewModel.displayPrices.isEmpty {
                        Button("重新載入") { Task { await viewModel.load() } }
                            .accessibilityHint("重新向 App Store 載入一次性支持選項")
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.warning) }
            }

            if viewModel.purchaseSucceeded {
                Section { Label("多謝你支持 VetMap！", systemImage: "heart.fill")
                        .foregroundStyle(AppTheme.primary) }
            }
        }
        .navigationTitle("支持開發")
        .task { await viewModel.load() }
    }
}
