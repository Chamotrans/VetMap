import CoreLocation
import SwiftUI

struct ClinicRowView: View {
    let clinic: VetClinic
    let currentLocation: CLLocation?
    let isSelected: Bool
    var onOpenDetails: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(clinic.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.88)

                        if clinic.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.primary)
                                .accessibilityLabel("已驗證")
                        }
                    }

                    Text(clinic.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Label(String(format: "%.1f", clinic.avgRating), systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.warning)

                    Text(clinic.distanceText(from: currentLocation))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                Label("\(clinic.reviewCount)", systemImage: "text.bubble.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(clinic.priceLevelText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .accessibilityLabel("價格等級 \(clinic.priceLevel)")

                ForEach(clinic.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .appChip(tint: AppTheme.accent)
                }
            }
            .lineLimit(1)

            if isSelected, let onOpenDetails {
                Button {
                    onOpenDetails()
                } label: {
                    Text("查看詳情")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(
            fill: Color(.systemBackground),
            stroke: isSelected ? AppTheme.primary.opacity(0.45) : AppTheme.hairline
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}

#Preview {
    ClinicRowView(
        clinic: MockClinicRepository.hkClinics[0],
        currentLocation: nil,
        isSelected: true,
        onOpenDetails: {}
    )
    .padding()
}
