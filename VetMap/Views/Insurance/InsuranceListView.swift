import SwiftUI

struct InsuranceListView: View {
    @Bindable var viewModel: InsuranceViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.plans.isEmpty {
                ProgressView("載入香港保險目錄…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.plans.isEmpty {
                ContentUnavailableView {
                    Label("未能載入保險目錄", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("重試") {
                        Task { await viewModel.loadPlans() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if viewModel.plans.isEmpty {
                ContentUnavailableView(
                    "暫未有保險資料",
                    systemImage: "shield",
                    description: Text("經審核的香港寵物保險資料將會顯示在此。")
                )
            } else {
                sortPicker

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.sortedPlans) { plan in
                            NavigationLink {
                                InsuranceDetailView(plan: plan, viewModel: viewModel)
                            } label: {
                                InsuranceCardView(plan: plan, viewModel: viewModel)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    InsuranceDisclaimerView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                }
            }
        }
        .organicBackground()
    }

    private var sortPicker: some View {
        HStack {
            Text("排序")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("排序", selection: $viewModel.sortOrder) {
                ForEach(InsuranceViewModel.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct InsuranceCardView: View {
    let plan: Insurance
    let viewModel: InsuranceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.providerName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.accent)

                    Text(plan.planName)
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("每月")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedPremium)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(AppTheme.warning)
                }
            }

            Text(plan.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(plan.coverage.prefix(3), id: \.self) { item in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .appCard()
    }

    private var formattedPremium: String {
        viewModel.formattedPremium(plan.monthlyPremium)
    }
}

struct InsuranceDisclaimerView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text("本目錄只提供保險公司官方連結及參考資料，不構成保險或財務建議。保費、保障及條款以供應商最新官方資料及報價為準。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(12)
        .appCard(fill: Color(.systemBackground))
    }
}

#Preview {
    NavigationStack {
        InsuranceListView(viewModel: InsuranceViewModel())
    }
}
