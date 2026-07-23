import SafariServices
import MapKit
import SwiftUI

struct ClinicDetailView: View {
    let clinic: VetClinic

    @State private var viewModel: ClinicDetailViewModel
    @State private var isAddingReview = false
    @State private var safariURL: URL?
    @State private var showPendingNotice = false
    @State private var showClinicReport = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    static let reportReasons = ["資料不實", "重複條目", "已結業", "冒犯內容", "其他"]

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

    private var visibleAverageRating: Double {
        guard !viewModel.visibleReviews.isEmpty else { return 0 }
        let total = viewModel.visibleReviews.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(viewModel.visibleReviews.count)
    }

    private var visibleOpeningHours: [(day: String, hours: String)] {
        clinic.openingHours.compactMap { day, hours in
            let trimmedDay = day.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedHours = hours.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDay.isEmpty, !trimmedHours.isEmpty else { return nil }
            return (trimmedDay, trimmedHours)
        }
        .sorted { $0.day < $1.day }
    }

    private var trimmedPhone: String {
        clinic.phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(clinic: VetClinic) {
        self.clinic = clinic
        _viewModel = State(wrappedValue: ClinicDetailViewModel(clinic: clinic))
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
                        if !clinic.services.isEmpty {
                            servicesSection
                                .transition(.opacity)
                        }
                        if !visibleOpeningHours.isEmpty {
                            openingHoursSection
                                .transition(.opacity)
                        }
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
            .refreshable {
                await viewModel.loadCommunityData()
            }
            .navigationTitle("診所詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: "VetMap - " + clinic.name + " - " + clinic.address) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            showClinicReport = true
                        } label: {
                            Label("舉報診所", systemImage: "flag")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
                    let succeeded = await viewModel.submitReviewForModeration(draft)
                    if succeeded {
                        showPendingNotice = true
                        return nil
                    }
                    return viewModel.storageError ?? "暫時無法提交評價。"
                }
            }
            .alert("已送出", isPresented: $showPendingNotice) {
                Button("好", role: .cancel) {}
            } message: {
                Text("評價已提交，待管理員審核後顯示。")
            }
            .confirmationDialog("舉報此診所", isPresented: $showClinicReport, titleVisibility: .visible) {
                ForEach(Self.reportReasons, id: \.self) { reason in
                    Button(reason) {
                        Task { _ = await viewModel.reportClinic(reason: reason) }
                    }
                }
                Button("取消", role: .cancel) {}
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
                ClinicAvatar(name: clinic.name, size: 52, font: .title2)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(clinic.name)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(clinic.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                if !viewModel.visibleReviews.isEmpty {
                    Label(String(format: "%.1f", visibleAverageRating), systemImage: "star.fill")
                        .foregroundStyle(AppTheme.warning)
                }

                Text("\(viewModel.visibleReviews.count) 則評價")
                    .foregroundStyle(.secondary)

                if clinic.priceLevel > 0 {
                    Text(clinic.priceLevelText)
                        .foregroundStyle(AppTheme.primary)
                        .accessibilityLabel("價格等級 \(clinic.priceLevel)")
                }
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var contactActions: some View {
        LazyVGrid(columns: actionColumns, spacing: 10) {
            if !trimmedPhone.isEmpty {
                Button {
                    if let phoneURL = URL(string: "tel:\(trimmedPhone)") {
                        openURL(phoneURL)
                    }
                } label: {
                    actionLabel("致電", systemImage: "phone.fill")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
                .accessibilityLabel("致電診所")
            }

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
                if !trimmedPhone.isEmpty {
                    infoRow("電話", trimmedPhone, systemImage: "phone")
                }
                infoRow("地址", clinic.address, systemImage: "mappin.and.ellipse")
                if let website = clinic.website {
                    infoRow("網站", website.host() ?? website.absoluteString, systemImage: "safari")
                }
                infoRow(
                    "資料狀態",
                    "已通過刊登審核",
                    systemImage: "checkmark.circle"
                )
            }
        }
    }

    private var reviewsSection: some View {
        detailCard(title: "社群評價", systemImage: "text.bubble.fill") {
            HStack(alignment: .center) {
                Label("\(viewModel.visibleReviews.count) 則近期回報", systemImage: "person.2.fill")
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

            if viewModel.visibleReviews.isEmpty {
                emptyCommunityState("暫時未有評價")
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.visibleReviews.prefix(2)) { review in
                        ReviewRowView(
                            review: review,
                            currency: defaultCurrency,
                            onMarkHelpful: {
                                Task { await viewModel.markHelpful(review.id) }
                            },
                            onReport: { reason in
                                Task { _ = await viewModel.reportReview(review, reason: reason) }
                            },
                            onBlockAuthor: {
                                Task { _ = await viewModel.blockUser(review.userId) }
                            }
                        )
                    }

                    NavigationLink {
                        ReviewListView(clinic: clinic)
                    } label: {
                        HStack {
                            Text("查看全部 \(viewModel.visibleReviews.count) 則評價")
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
            if viewModel.visibleQuotes.isEmpty {
                VStack(spacing: 12) {
                    emptyCommunityState("暫無報價記錄")

                    NavigationLink {
                        QuoteListView(clinicId: clinic.id, clinicName: clinic.name)
                    } label: {
                        Label("分享第一筆報價", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                AppTheme.primary.opacity(0.12),
                                in: RoundedRectangle(
                                    cornerRadius: AppTheme.cardRadius,
                                    style: .continuous
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.visibleQuotes.prefix(2)) { quote in
                        quoteRow(quote)
                    }

                    NavigationLink {
                        QuoteListView(clinicId: clinic.id, clinicName: clinic.name)
                    } label: {
                        HStack {
                            Text("查看全部 \(viewModel.visibleQuotes.count) 筆報價")
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
                ForEach(visibleOpeningHours, id: \.day) { day, hours in
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

                Menu {
                    Button(role: .destructive) {
                        Task {
                            _ = await viewModel.reportQuote(quote, reason: "內容不實或不當")
                        }
                    } label: {
                        Label("舉報報價", systemImage: "flag")
                    }
                    Button(role: .destructive) {
                        Task { _ = await viewModel.blockUser(quote.userId) }
                    } label: {
                        Label("封鎖作者", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
        "HKD"
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
