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
                } else if let price = viewModel.displayPrice {
                    Button {
                        Task { await viewModel.purchase() }
                    } label: {
                        HStack {
                            Label("請開發團隊飲杯嘢", systemImage: "cup.and.saucer.fill")
                            Spacer()
                            Text(price).monospacedDigit()
                        }
                    }
                    .disabled(viewModel.isPurchasing)
                    .accessibilityHint("一次性支持，並非訂閱或自動續期")
                } else {
                    Button("重新載入") { Task { await viewModel.load() } }
                        .accessibilityHint("重新向 App Store 載入一次性支持選項")
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
