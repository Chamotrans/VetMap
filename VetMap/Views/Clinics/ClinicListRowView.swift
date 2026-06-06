import SwiftUI

struct ClinicListRowView: View {
    let clinic: VetClinic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(clinic.name)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            if clinic.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(AppTheme.primary)
                                    .accessibilityLabel("已驗證")
                            }
                        }

                        Text(clinic.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                metrics

                FlowLayout(spacing: 6) {
                    ForEach(clinic.services.prefix(3), id: \.self) { service in
                        Text(service)
                            .appChip(tint: AppTheme.accent)
                    }
                }
            }
        }
        .padding(14)
        .appCard()
    }

    private var statusIcon: some View {
        Image(systemName: clinic.verified ? "cross.case.fill" : "cross.case")
            .font(.headline)
            .foregroundStyle(clinic.verified ? .white : AppTheme.primary)
            .frame(width: 42, height: 42)
            .background(
                clinic.verified ? AppTheme.primary : AppTheme.primary.opacity(0.11),
                in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            Label(String(format: "%.1f", clinic.avgRating), systemImage: "star.fill")
                .foregroundStyle(AppTheme.warning)

            Label("\(clinic.reviewCount)", systemImage: "text.bubble.fill")
                .foregroundStyle(.secondary)

            Text(clinic.priceLevelText)
                .foregroundStyle(AppTheme.primary)
                .accessibilityLabel("價格等級 \(clinic.priceLevel)")
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
    }
}

#Preview {
    ClinicListRowView(clinic: MockClinicRepository.hkClinics[0])
        .padding()
        .background(Color(.systemGroupedBackground))
}
