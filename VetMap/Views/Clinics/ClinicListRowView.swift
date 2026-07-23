import SwiftUI

struct ClinicListRowView: View {
    let clinic: VetClinic

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clinic.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

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

                if clinic.priceLevel > 0 {
                    metrics
                }

                if !clinic.services.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(clinic.services.prefix(3), id: \.self) { service in
                            Text(service)
                                .appChip(tint: AppTheme.accent)
                        }
                    }
                }
            }
        }
        .padding(14)
        .appCard()
        .pressScale()
    }

    private var statusIcon: some View {
        ClinicAvatarSmall(name: clinic.name)
    }

    private var metrics: some View {
        HStack(spacing: 10) {
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
