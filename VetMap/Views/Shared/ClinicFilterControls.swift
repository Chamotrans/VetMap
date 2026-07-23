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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                regionMenu
                priceMenu

                if filter.isActive {
                    clearButton
                }
            }
            .padding(.vertical, 1)
        }
        .scrollClipDisabled()
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
