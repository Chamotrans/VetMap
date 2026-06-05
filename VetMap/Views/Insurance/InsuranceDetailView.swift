import SwiftUI

struct InsuranceDetailView: View {
    let plan: Insurance
    @ObservedObject var viewModel: InsuranceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection

                premiumSection

                coverageSection

                exclusionsSection

                contactSection

                websiteButton

                similarPlansSection
            }
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("方案詳情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(plan.providerName)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.accent)

            Text(plan.planName)
                .font(.title2.weight(.bold))

            Text(plan.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(fill: Color(.systemBackground))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var premiumSection: some View {
        HStack(spacing: 16) {
            premiumBox(title: "月繳保費", amount: plan.monthlyPremium)
            premiumBox(title: "年繳保費", amount: plan.annualPremium)
        }
        .padding(.horizontal, 16)
    }

    private func premiumBox(title: String, amount: Decimal) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedCurrency(amount))
                .font(.title3.weight(.heavy))
                .foregroundStyle(AppTheme.warning)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .appCard(fill: AppTheme.warning.opacity(0.06), stroke: AppTheme.warning.opacity(0.18))
    }

    private var coverageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("保障範圍", systemImage: "checkmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.coverage, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.top, 2)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(14)
            .appCard(fill: .green.opacity(0.05), stroke: .green.opacity(0.15))
        }
        .padding(.horizontal, 16)
    }

    private var exclusionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("不保事項", systemImage: "xmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.exclusions, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.top, 2)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .appCard(fill: .red.opacity(0.05), stroke: .red.opacity(0.15))
        }
        .padding(.horizontal, 16)
    }

    private var contactSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "phone.fill")
                .foregroundStyle(AppTheme.primary)
            Text("聯絡電話：")
                .font(.subheadline.weight(.medium))
            Text(plan.contactPhone)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .appCard()
        .padding(.horizontal, 16)
    }

    private var websiteButton: some View {
        Button {
            UIApplication.shared.open(plan.website)
        } label: {
            HStack {
                Image(systemName: "globe")
                Text("前往官網")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var similarPlansSection: some View {
        let similar = viewModel.plansWithSimilarPremium(to: plan)

        if !similar.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("其他相似保費方案")
                    .font(.headline)
                    .padding(.horizontal, 16)

                VStack(spacing: 10) {
                    ForEach(similar) { other in
                        NavigationLink {
                            InsuranceDetailView(plan: other, viewModel: viewModel)
                        } label: {
                            similarPlanRow(other)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func similarPlanRow(_ plan: Insurance) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.providerName)
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                Text(plan.planName)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            Text(formattedCurrency(plan.monthlyPremium))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.warning)
        }
        .padding(12)
        .appCard()
    }

    private func formattedCurrency(_ amount: Decimal) -> String {
        let symbol = viewModel.currency(for: plan) == "HKD" ? "HK$" : "NT$"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return "\(symbol)\(value)"
    }
}

#Preview {
    NavigationStack {
        InsuranceDetailView(
            plan: MockInsuranceRepository.seedPlans[0],
            viewModel: InsuranceViewModel()
        )
    }
}
