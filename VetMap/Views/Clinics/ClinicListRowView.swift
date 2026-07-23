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
                                    .accessibilityLabel("已審核刊登")
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
        .pressScale()
    }

    private var statusIcon: some View {
        ZStack(alignment: .topTrailing) {
            ClinicAvatarSmall(name: clinic.name)

            if clinic.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary)
                    .background(Circle().fill(Color(.systemBackground)).frame(width: 14, height: 14))
                    .offset(x: 4, y: -2)
                    .accessibilityLabel("已審核刊登")
            }
        }
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
