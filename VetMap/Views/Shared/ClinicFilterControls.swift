import SwiftUI

struct ClinicSearchField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜尋")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color(.systemBackground).opacity(0.94), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }
}

struct ClinicFilterControls: View {
    @Binding var filter: ClinicSearchFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    availabilityMenu
                    regionMenu
                    priceMenu

                    if filter.isActive {
                        clearButton
                    }
                }
                .padding(.vertical, 1)
            }
            .scrollClipDisabled()

            if let limitationMessage = filter.availability.limitationMessage {
                Label(limitationMessage, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(limitationMessage)
            }
        }
    }

    private var availabilityMenu: some View {
        Menu {
            Picker("營業狀態", selection: $filter.availability) {
                ForEach(ClinicSearchFilter.Availability.allCases) { availability in
                    Text(availability.rawValue).tag(availability)
                }
            }
        } label: {
            ClinicFilterChip(
                title: filter.availability.title,
                systemImage: "clock",
                isActive: filter.availability != .all,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("營業狀態篩選")
    }

    private var regionMenu: some View {
        Menu {
            Picker("地區", selection: $filter.region) {
                ForEach(ClinicSearchFilter.Region.allCases) { region in
                    Text(region.rawValue).tag(region)
                }
            }
        } label: {
            ClinicFilterChip(
                title: filter.region.title,
                systemImage: "mappin.and.ellipse",
                isActive: filter.region != .all,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("地區篩選")
    }

    private var priceMenu: some View {
        Menu {
            Picker("價格", selection: $filter.price) {
                ForEach(ClinicSearchFilter.Price.allCases) { price in
                    Text(price.rawValue).tag(price)
                }
            }
        } label: {
            ClinicFilterChip(
                title: filter.price.title,
                systemImage: "dollarsign.circle",
                isActive: filter.price != .all,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("價格篩選")
    }

    private var clearButton: some View {
        Button {
            filter = ClinicSearchFilter()
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(Color(.systemBackground).opacity(0.94), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("清除篩選")
    }
}

struct ClinicAvailabilityBadge: View {
    let clinic: VetClinic
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            if let label = clinic.availabilityLabel(at: context.date) {
                Label(label, systemImage: systemImage(at: context.date))
                    .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(foregroundStyle(at: context.date))
                    .padding(.horizontal, compact ? 7 : 9)
                    .padding(.vertical, compact ? 4 : 5)
                    .background(
                        foregroundStyle(at: context.date).opacity(0.12),
                        in: Capsule()
                    )
                    .lineLimit(1)
                    .accessibilityLabel(label)
            }
        }
    }

    private func systemImage(at date: Date) -> String {
        switch clinic.operatingStatus(at: date) {
        case .open24Hours:
            return "clock.badge.checkmark"
        case .open:
            return "door.left.hand.open"
        case .closed where clinic.hasCurrentNightService(at: date):
            return "moon.stars.fill"
        case .closed, .unavailable:
            return "clock"
        }
    }

    private func foregroundStyle(at date: Date) -> Color {
        switch clinic.operatingStatus(at: date) {
        case .open24Hours, .open:
            return AppTheme.primary
        case .closed where clinic.hasCurrentNightService(at: date):
            return AppTheme.accent
        case .closed, .unavailable:
            return .gray
        }
    }
}

private struct ClinicFilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)

            Text(title)
                .fontWeight(.semibold)

            if showsChevron {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
            isActive ? AppTheme.primary : Color(.systemBackground).opacity(0.94),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(isActive ? AppTheme.primary.opacity(0.35) : AppTheme.hairline, lineWidth: 1)
        )
    }
}
