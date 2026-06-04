import MapKit
import SwiftUI

struct ClinicDetailView: View {
    let clinic: VetClinic

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let actionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: clinic.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    contactActions
                    infoSection
                    servicesSection
                    openingHoursSection
                    mapSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("診所詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cross.case.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(clinic.name)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)

                        if clinic.verified {
                                Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(AppTheme.primary)
                                .accessibilityLabel("已驗證")
                        }
                    }

                    Text(clinic.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Label(String(format: "%.1f", clinic.avgRating), systemImage: "star.fill")
                    .foregroundStyle(AppTheme.warning)

                Text("\(clinic.reviewCount) 則評價")
                    .foregroundStyle(.secondary)

                Text(clinic.priceLevelText)
                    .foregroundStyle(AppTheme.primary)
                    .accessibilityLabel("價格等級 \(clinic.priceLevel)")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var contactActions: some View {
        LazyVGrid(columns: actionColumns, spacing: 10) {
            Button {
                if let phoneURL = URL(string: "tel:\(clinic.phone)") {
                    openURL(phoneURL)
                }
            } label: {
                actionLabel("致電", systemImage: "phone.fill")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
            .tint(AppTheme.primary)
            .disabled(clinic.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let website = clinic.website {
                Button {
                    openURL(website)
                } label: {
                    actionLabel("網站", systemImage: "safari.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
            }

            Button {
                openInMaps()
            } label: {
                actionLabel("路線", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
        }
    }

    private var infoSection: some View {
        detailCard(title: "基本資料", systemImage: "info.circle.fill") {
            VStack(alignment: .leading, spacing: 12) {
                infoRow("電話", clinic.phone, systemImage: "phone")
                infoRow("地址", clinic.address, systemImage: "mappin.and.ellipse")
                if let website = clinic.website {
                    infoRow("網站", website.host() ?? website.absoluteString, systemImage: "safari")
                }
                infoRow("資料狀態", clinic.verified ? "社群已驗證" : "待更多社群回報", systemImage: clinic.verified ? "checkmark.seal" : "exclamationmark.triangle")
            }
        }
    }

    private var servicesSection: some View {
        detailCard(title: "服務項目", systemImage: "stethoscope") {
            FlowLayout(spacing: 8) {
                ForEach(clinic.services, id: \.self) { service in
                    Text(service)
                        .font(.subheadline.weight(.medium))
                        .appChip(tint: AppTheme.primary)
                }
            }
        }
    }

    private var openingHoursSection: some View {
        detailCard(title: "營業時間", systemImage: "clock.fill") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(clinic.openingHours.sorted(by: { $0.key < $1.key }), id: \.key) { day, hours in
                    HStack {
                        Text(day)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(hours)
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    private var mapSection: some View {
        detailCard(title: "位置", systemImage: "map.fill") {
            Map(initialPosition: .region(mapRegion)) {
                Marker(clinic.name, systemImage: "cross.case.fill", coordinate: clinic.mapCoordinate)
                    .tint(.teal)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .allowsHitTesting(false)

            Button {
                openInMaps()
            } label: {
                Label("在地圖中開啟", systemImage: "map")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
        }
    }

    private func detailCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private func infoRow(_ title: String, _ value: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func openInMaps() {
        let placemark = MKPlacemark(coordinate: clinic.mapCoordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = clinic.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }

            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    ClinicDetailView(clinic: MockClinicRepository.clinics[0])
}
