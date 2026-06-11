import SwiftUI

struct InsuranceListView: View {
    @Bindable var viewModel: InsuranceViewModel

    var body: some View {
        VStack(spacing: 0) {
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
                .padding(.vertical, 12)
            }
        }
        .background(AppTheme.screenBackground)
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
        .background(Color(.systemBackground))
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
        let symbol = viewModel.currency(for: plan) == "HKD" ? "HK$" : "NT$"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: plan.monthlyPremium as NSDecimalNumber) ?? "\(plan.monthlyPremium)"
        return "\(symbol)\(amount)"
    }
}

#Preview {
    NavigationStack {
        InsuranceListView(viewModel: InsuranceViewModel())
    }
}
