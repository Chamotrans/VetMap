import SafariServices
import MapKit
import SwiftUI

struct ClinicDetailView: View {
    let clinic: VetClinic

    @StateObject private var viewModel: ClinicDetailViewModel
    @State private var isAddingReview = false
    @State private var safariURL: URL?
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

    init(clinic: VetClinic) {
        self.clinic = clinic
        _viewModel = StateObject(wrappedValue: ClinicDetailViewModel(clinic: clinic))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if viewModel.isLoading {
                        shimmerSections
                            .transition(.opacity)
                    } else {
                        header
                            .transition(.opacity)
                        contactActions
                            .transition(.opacity)
                        storageErrorBanner
                            .transition(.opacity)
                        infoSection
                            .transition(.opacity)
                        reviewsSection
                            .transition(.opacity)
                        quoteSection
                            .transition(.opacity)
                        servicesSection
                            .transition(.opacity)
                        openingHoursSection
                            .transition(.opacity)
                        mapSection
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("診所詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: "VetMap - " + clinic.name + " - " + clinic.address) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAddingReview) {
                AddReviewView(clinicName: clinic.name) { draft in
                    viewModel.addReview(draft)
                }
            }
            .sheet(isPresented: Binding(
                get: { safariURL != nil },
                set: { if !$0 { safariURL = nil } }
            )) {
                if let url = safariURL {
                    SafariViewController(url: url)
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
            .accessibilityLabel("致電診所")

            if let website = clinic.website {
                Button {
                    safariURL = website
                } label: {
                    actionLabel("網站", systemImage: "safari.fill")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .accessibilityLabel("診所網站")
            }

            Button {
                openInMaps()
            } label: {
                actionLabel("路線", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
            .accessibilityLabel("導航到此診所")
        }
    }

    private var shimmerSections: some View {
        Group {
            ShimmerCard()
            ShimmerCard()
            ShimmerCard()
            ShimmerCard()
        }
    }

    @ViewBuilder
    private var storageErrorBanner: some View {
        if let storageError = viewModel.storageError {
            Label(storageError, systemImage: "externaldrive.badge.exclamationmark")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.warning)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(fill: AppTheme.warning.opacity(0.12), stroke: AppTheme.warning.opacity(0.22))
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

    private var reviewsSection: some View {
        detailCard(title: "社群評價", systemImage: "text.bubble.fill") {
            HStack(alignment: .center) {
                Label("\(viewModel.reviews.count) 則近期回報", systemImage: "person.2.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    isAddingReview = true
                } label: {
                    Label("新增", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
            }

            if viewModel.reviews.isEmpty {
                emptyCommunityState("暫時未有評價")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.reviews.prefix(2)) { review in
                        ReviewRowView(
                            review: review,
                            currency: defaultCurrency,
                            onMarkHelpful: { viewModel.markHelpful(review.id) }
                        )
                    }

                    NavigationLink {
                        ReviewListView(clinic: clinic)
                    } label: {
                        HStack {
                            Text("查看全部 \(viewModel.reviews.count) 則評價")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .accessibilityLabel("查看評價")
    }

    @ViewBuilder
    private var quoteSection: some View {
        detailCard(title: "費用報價", systemImage: "dollarsign.circle.fill") {
            if viewModel.quotes.isEmpty {
                emptyCommunityState("暫無報價記錄")
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.quotes.prefix(2)) { quote in
                        quoteRow(quote)
                    }

                    NavigationLink {
                        QuoteListView(clinicId: clinic.id, clinicName: clinic.name)
                    } label: {
                        HStack {
                            Text("查看全部 \(viewModel.quotes.count) 筆報價")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
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

    private func quoteRow(_ quote: Quote) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(quote.treatmentType)
                    .font(.subheadline.weight(.semibold))

                Text(quote.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(costText(quote.actualCost ?? quote.estimatedCost, currency: quote.currency))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)

                if quote.actualCost == nil {
                    Text("估算")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private func emptyCommunityState(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .foregroundStyle(AppTheme.primary)
                .frame(width: 36, height: 36)
                .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private func costText(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let number = NSDecimalNumber(decimal: amount)
        return "\(currency) \(formatter.string(from: number) ?? number.stringValue)"
    }

    private var defaultCurrency: String {
        clinic.address.localizedCaseInsensitiveContains("香港") ? "HKD" : "TWD"
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
    ClinicDetailView(clinic: MockClinicRepository.hkClinics[0])
}

// MARK: - Safari View Controller


struct SafariViewController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
