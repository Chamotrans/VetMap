import CoreLocation
import Foundation
import SwiftUI

struct ClinicRowView: View {
    let clinic: VetClinic
    let currentLocation: CLLocation?
    let availabilityDate: Date
    let isSelected: Bool
    var isUrgentMode = false
    var onCall: (() -> Void)? = nil
    var onNavigate: (() -> Void)? = nil
    var onOpenDetails: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(clinic.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)

                    Text(clinic.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    ClinicAvailabilityBadge(clinic: clinic, compact: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(clinic.distanceText(from: currentLocation))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            if !clinic.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(clinic.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .appChip(tint: AppTheme.accent)
                    }
                }
                .lineLimit(1)
            }

            if isSelected, let onOpenDetails {
                if isUrgentMode {
                    urgentActions
                } else {
                    detailsButton(onOpenDetails)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(
            fill: Color(.systemBackground),
            stroke: isSelected ? AppTheme.primary.opacity(0.45) : AppTheme.hairline
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var accessibilityLabel: String {
        let availability = clinic.availabilityLabel(at: availabilityDate)
            ?? "營業狀態未提供"
        let distance = clinic.distanceText(from: currentLocation)
        return "\(clinic.name)，\(availability)，\(distance)"
    }

    private var callablePhone: String? {
        guard let firstNumber = clinic.phone
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { "/,;|".contains($0) })
            .first
        else {
            return nil
        }

        let normalized = firstNumber.filter { $0.isNumber || $0 == "+" }
        return normalized.isEmpty ? nil : normalized
    }

    @ViewBuilder
    private var urgentActions: some View {
        HStack(spacing: 8) {
            if callablePhone != nil, let onCall {
                urgentActionButton("致電", systemImage: "phone.fill", action: onCall)
            }
            if clinic.mapCoordinate != nil, let onNavigate {
                urgentActionButton("導航", systemImage: "arrow.triangle.turn.up.right.diamond.fill", action: onNavigate)
            }
            if let onOpenDetails {
                urgentActionButton("詳情", systemImage: "info.circle.fill", action: onOpenDetails)
            }
        }
    }

    private func urgentActionButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: AppTheme.compactRadius))
        .tint(AppTheme.primary)
    }

    private func detailsButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
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

#Preview {
    ClinicRowView(
        clinic: MockClinicRepository.hkClinics[0],
        currentLocation: nil,
        availabilityDate: Date(),
        isSelected: true,
        onOpenDetails: {}
    )
    .padding()
}
