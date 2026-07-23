import SwiftUI

private enum ClinicBrowseMode: String, CaseIterable {
    case list, grid, detail

    var next: ClinicBrowseMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    var icon: String {
        switch self {
        case .list:   "list.bullet"
        case .grid:   "square.grid.2x2"
        case .detail: "rectangle.stack"
        }
    }

    var label: String {
        switch self {
        case .list:   "列表"
        case .grid:   "格覽"
        case .detail: "詳細"
        }
    }
}

private enum ClinicDirectoryMode: String, CaseIterable, Identifiable {
    case official
    case community

    var id: String { rawValue }

    var label: String {
        switch self {
        case .official: "台灣官方登記"
        case .community: "社群地圖診所"
        }
    }
}

private enum ClinicSubmissionError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

struct ClinicListView: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @State private var viewModel = ClinicsViewModel()
    @State private var clinicForDetail: VetClinic?
    @State private var isAddingClinic = false
    @State private var showLogin = false
    @State private var addClinicAfterLogin = false
    @State private var directoryMode: ClinicDirectoryMode =
        AppLaunchFlags.autoPresentClinic ? .community : .official
    @AppStorage("clinicViewMode") private var rawViewMode = ClinicBrowseMode.detail.rawValue
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var viewMode: ClinicBrowseMode {
        ClinicBrowseMode(rawValue: rawViewMode) ?? .detail
    }

    private var navigationCount: Int {
        switch directoryMode {
        case .official: viewModel.filteredOfficialClinics.count
        case .community: viewModel.filteredClinics.count
        }
    }

    private var searchText: Binding<String> {
        Binding(
            get: {
                switch directoryMode {
                case .official: viewModel.officialQuery
                case .community: viewModel.filter.query
                }
            },
            set: { newValue in
                switch directoryMode {
                case .official: viewModel.officialQuery = newValue
                case .community: viewModel.filter.query = newValue
                }
            }
        )
    }

    private var searchPrompt: String {
        switch directoryMode {
        case .official: "搜尋機構、地址、縣市或執照"
        case .community: "搜尋診所、地區、服務"
        }
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            ipadLayout
        } else {
            iphoneLayout
        }
    }

    // MARK: - Layouts

    private var iphoneLayout: some View {
        NavigationStack {
            clinicListContent
                .navigationTitle("獸醫診所 (\(navigationCount))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: searchText, prompt: searchPrompt)
                .onSubmit(of: .search) { Analytics.searchPerformed(searchText.wrappedValue) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if directoryMode == .community {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    rawViewMode = viewMode.next.rawValue
                                }
                            } label: {
                                Image(systemName: viewMode.next.icon)
                            }
                            .accessibilityLabel("切換為\(viewMode.next.label)模式")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if directoryMode == .community {
                            Button { requestAddClinic() } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("新增診所")
                        }
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if directoryMode == .community {
                        Button { requestAddClinic() } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(AppTheme.primary, in: Circle())
                                .clipShape(Circle())
                                .liquidGlassCapsule(tint: AppTheme.primary)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                        .accessibilityLabel("新增診所")
                    }
                }
                .sheet(item: $clinicForDetail) { clinic in
                    ClinicDetailView(clinic: clinic)
                }
                .sheet(isPresented: $isAddingClinic) {
                    AddClinicView(
                        successMessage: "已送出，待審核"
                    ) { clinic in
                        guard await viewModel.submitClinicForModeration(clinic) else {
                            throw ClinicSubmissionError.failed(
                                viewModel.storageError ?? "暫時無法提交診所資料。"
                            )
                        }
                    }
                }
                .fullScreenCover(isPresented: $showLogin, onDismiss: {
                    if authViewModel.authState != .signedIn {
                        addClinicAfterLogin = false
                    }
                }) {
                    LoginView(authViewModel: authViewModel)
                }
                .onChange(of: authViewModel.authState) { _, newState in
                    guard newState == .signedIn, addClinicAfterLogin else { return }
                    addClinicAfterLogin = false
                    showLogin = false
                    isAddingClinic = true
                }
        }
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            clinicListContent
                .navigationTitle("獸醫診所 (\(navigationCount))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: searchText, prompt: searchPrompt)
                .onSubmit(of: .search) { Analytics.searchPerformed(searchText.wrappedValue) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if directoryMode == .community {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    rawViewMode = viewMode.next.rawValue
                                }
                            } label: {
                                Image(systemName: viewMode.next.icon)
                            }
                            .accessibilityLabel("切換為\(viewMode.next.label)模式")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        if directoryMode == .community {
                            Button { requestAddClinic() } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("新增診所")
                        }
                    }
                }
                .sheet(isPresented: $isAddingClinic) {
                    AddClinicView(
                        successMessage: "已送出，待審核"
                    ) { clinic in
                        guard await viewModel.submitClinicForModeration(clinic) else {
                            throw ClinicSubmissionError.failed(
                                viewModel.storageError ?? "暫時無法提交診所資料。"
                            )
                        }
                    }
                }
                .fullScreenCover(isPresented: $showLogin, onDismiss: {
                    if authViewModel.authState != .signedIn {
                        addClinicAfterLogin = false
                    }
                }) {
                    LoginView(authViewModel: authViewModel)
                }
                .onChange(of: authViewModel.authState) { _, newState in
                    guard newState == .signedIn, addClinicAfterLogin else { return }
                    addClinicAfterLogin = false
                    showLogin = false
                    isAddingClinic = true
                }
        } detail: {
            if let clinic = clinicForDetail {
                NavigationStack { ClinicDetailView(clinic: clinic) }
            } else {
                ContentUnavailableView(
                    "選擇診所",
                    systemImage: "cross.case",
                    description: Text("從列表中選擇一間診所以查看詳情")
                )
            }
        }
    }

    // MARK: - Content

    private var clinicListContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                directoryModePicker

                switch directoryMode {
                case .official:
                    officialHeader
                    officialFilterBar
                    officialErrorBanner
                    officialResultsSummary
                    officialRows
                    officialAttribution
                case .community:
                    header
                    filterBar
                    storageErrorBanner
                    resultsSummary
                    clinicRows

                    Text("資料由社群投稿，經管理員審核後公開")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .refreshable { await viewModel.retryLoad() }
        .organicBackground()
        .onAppear {
            Task {
                await viewModel.loadClinics()
                if AppLaunchFlags.autoPresentClinic, clinicForDetail == nil {
                    directoryMode = .community
                    clinicForDetail = viewModel.filteredClinics.first
                }
            }
        }
    }

    // MARK: - Subviews

    private var directoryModePicker: some View {
        Picker("資料類型", selection: $directoryMode) {
            ForEach(ClinicDirectoryMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("選擇診所資料類型")
    }

    private var officialHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(
                    AppTheme.primary,
                    in: RoundedRectangle(
                        cornerRadius: AppTheme.cardRadius,
                        style: .continuous
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("台灣官方開業執照")
                    .font(.headline.weight(.semibold))
                Text("由雲端載入農業部公開登記資料，不使用推算或假座標。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var officialFilterBar: some View {
        HStack(spacing: 12) {
            Label("縣市", systemImage: "mappin.and.ellipse")
                .font(.subheadline.weight(.semibold))

            Spacer()

            Picker("縣市", selection: $viewModel.officialCity) {
                ForEach(viewModel.officialCities, id: \.self) { city in
                    Text(city).tag(city)
                }
            }
            .pickerStyle(.menu)

            if viewModel.officialCity != "全部縣市"
                || !viewModel.officialQuery
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("清除") {
                    viewModel.officialCity = "全部縣市"
                    viewModel.officialQuery = ""
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(12)
        .appCard()
        .accessibilityLabel("官方診所縣市篩選")
    }

    @ViewBuilder
    private var officialErrorBanner: some View {
        if let error = viewModel.officialError {
            Label(error, systemImage: "externaldrive.badge.exclamationmark")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.warning)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(
                    fill: AppTheme.warning.opacity(0.12),
                    stroke: AppTheme.warning.opacity(0.22)
                )
        }
    }

    private var officialResultsSummary: some View {
        HStack {
            Text(
                viewModel.filteredOfficialClinics.count == viewModel.officialClinics.count
                    ? "\(viewModel.officialClinics.count) 筆官方登記"
                    : "\(viewModel.filteredOfficialClinics.count) / \(viewModel.officialClinics.count) 筆官方登記"
            )
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)

            Spacer()

            Text(viewModel.officialFilterDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var officialRows: some View {
        if viewModel.officialClinics.isEmpty && viewModel.isLoadingOfficial {
            ProgressView("正在載入台灣官方登記")
                .frame(maxWidth: .infinity)
                .padding(32)
                .appCard()
                .padding(.top, 20)
        } else if viewModel.officialClinics.isEmpty {
            if let error = viewModel.officialError {
                ErrorRetryView(
                    icon: "wifi.slash",
                    title: "無法載入官方診所資料",
                    message: LocalizedStringKey(error),
                    retryLabel: "重試",
                    onRetry: { Task { await viewModel.retryLoad() } }
                )
                .padding(.top, 20)
            } else {
                EmptyStateView(
                    icon: "building.columns",
                    title: "暫未有官方登記資料",
                    subtitle: "雲端尚未發佈可驗證的官方資料快照。"
                )
                .padding(.top, 20)
            }
        } else if viewModel.filteredOfficialClinics.isEmpty {
            EmptyStateView(
                icon: "magnifyingglass",
                title: "找不到相關官方登記",
                subtitle: "請改用機構名稱、地址、縣市或執照號碼搜尋。",
                action: (
                    "清除篩選",
                    {
                        viewModel.officialCity = "全部縣市"
                        viewModel.officialQuery = ""
                    }
                )
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredOfficialClinics) { clinic in
                    OfficialClinicRow(clinic: clinic)
                }
            }
        }
    }

    @ViewBuilder
    private var officialAttribution: some View {
        if let manifest = viewModel.officialManifest,
           let sourceURL = URL(string: manifest.sourceURL),
           let licenseURL = URL(string: manifest.licenseURL) {
            VStack(alignment: .leading, spacing: 8) {
                Label("資料來源與授權", systemImage: "doc.text.magnifyingglass")
                    .font(.footnote.weight(.semibold))

                Link(manifest.sourceName, destination: sourceURL)
                    .font(.caption)

                Text("資料快照：\(manifest.snapshotDate)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Link("政府資料開放授權條款（OGDL-Taiwan 1.0）", destination: licenseURL)
                    .font(.caption)

                Text("登記狀態只反映官方資料快照，不代表目前營業時間、診療品質或 VetMap 推薦。地址沒有附帶座標；「Apple 地圖」會以地址即時搜尋。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard(
                fill: AppTheme.primary.opacity(0.07),
                stroke: AppTheme.primary.opacity(0.16)
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("社群回報")
                    .font(.headline.weight(.semibold))
                Text("社群投稿會安全送到雲端，經管理員審核後公開。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }

    private var filterBar: some View {
        ClinicFilterControls(filter: $viewModel.filter)
            .padding(10)
            .appCard()
            .accessibilityLabel("診所篩選")
    }

    private var resultsSummary: some View {
        HStack {
            Text(resultCountText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.filter.activeDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
    }

    private var resultCountText: String {
        viewModel.filter.isActive
            ? "\(viewModel.filteredClinics.count) / \(viewModel.clinics.count) 間診所"
            : "\(viewModel.filteredClinics.count) 間診所"
    }

    @ViewBuilder
    private var storageErrorBanner: some View {
        if let err = viewModel.storageError {
            Label(err, systemImage: "externaldrive.badge.exclamationmark")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.warning)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard(fill: AppTheme.warning.opacity(0.12), stroke: AppTheme.warning.opacity(0.22))
        }
    }

    // MARK: - Clinic Rows (3 modes)

    @ViewBuilder
    private var clinicRows: some View {
        if viewModel.clinics.isEmpty && viewModel.isLoading {
            ProgressView("正在載入診所資料")
                .frame(maxWidth: .infinity)
                .padding(32)
                .appCard()
                .padding(.top, 20)
        } else if viewModel.clinics.isEmpty {
            if let networkError = viewModel.networkError {
                dataLoadErrorView(networkError)
            } else {
                noApprovedClinicsView
            }
        } else if viewModel.filteredClinics.isEmpty {
            emptyState
        } else {
            Group {
                switch viewMode {
                case .list:
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredClinics) { clinic in
                            clinicButton(clinic) { ClinicSlimRow(clinic: clinic) }
                        }
                    }
                case .grid:
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(viewModel.filteredClinics) { clinic in
                            clinicButton(clinic) { ClinicGridCard(clinic: clinic) }
                        }
                    }
                case .detail:
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.filteredClinics) { clinic in
                            clinicButton(clinic) { ClinicListRowView(clinic: clinic) }
                        }
                    }
                }
            }
            .animation(.default, value: viewModel.filteredClinics)
        }
    }

    @ViewBuilder
    private func clinicButton<Label: View>(_ clinic: VetClinic, @ViewBuilder label: () -> Label) -> some View {
        Button { clinicForDetail = clinic } label: { label() }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                if viewModel.isPinned(clinic.id) {
                    Image(systemName: "pin.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(AppTheme.primary, in: Circle())
                        .offset(x: 6, y: 6)
                        .accessibilityLabel("已置頂")
                }
            }
            .accessibilityLabel("\(clinic.name), 評分 \(String(format: "%.1f", clinic.avgRating))")
            .accessibilityHint("開啟診所詳情")
            .accessibilitySortPriority(1)
    }

    private var noApprovedClinicsView: some View {
        EmptyStateView(
            icon: "cross.case.fill",
            title: "暫未有已審核診所",
            subtitle: "你可以提交診所資料，經管理員審核後會公開。",
            action: ("新增診所", requestAddClinic)
        )
        .padding(.top, 20)
    }

    private func requestAddClinic() {
        guard authViewModel.authState == .signedIn else {
            addClinicAfterLogin = true
            showLogin = true
            return
        }
        isAddingClinic = true
    }

    private func dataLoadErrorView(_ message: String) -> some View {
        ErrorRetryView(
            icon: "wifi.slash",
            title: "無法載入診所資料",
            message: LocalizedStringKey(message),
            retryLabel: "重試",
            onRetry: { Task { await viewModel.retryLoad() } }
        )
        .padding(.top, 20)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "找不到相關診所",
            subtitle: "試試放寬篩選，或改用地區、服務項目搜尋。",
            action: viewModel.filter.isActive
                ? ("清除篩選", { viewModel.filter = ClinicSearchFilter() })
                : nil
        )
    }
}

// MARK: - Taiwan official licence row

private struct OfficialClinicRow: View {
    let clinic: OfficialClinicRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "building.2.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 38, height: 38)
                    .background(
                        AppTheme.primary.opacity(0.11),
                        in: RoundedRectangle(
                            cornerRadius: AppTheme.compactRadius,
                            style: .continuous
                        )
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(clinic.institutionName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(clinic.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            FlowLayout(spacing: 6) {
                Text(clinic.city)
                    .appChip(tint: AppTheme.primary)
                Text("狀態：\(clinic.licenseStatus)")
                    .appChip(tint: .green)
                Text(clinic.licenseType)
                    .appChip(tint: AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("執照：\(clinic.licenseNumber)", systemImage: "doc.text")
                if !clinic.phone.isEmpty {
                    Label(clinic.phone, systemImage: "phone")
                }
                if let formattedIssueDate {
                    Label("發照日期：\(formattedIssueDate)", systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if let phoneURL {
                    Link(destination: phoneURL) {
                        Label("致電", systemImage: "phone.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(
                        .roundedRectangle(radius: AppTheme.compactRadius)
                    )
                }

                if let mapsURL {
                    Link(destination: mapsURL) {
                        Label("Apple 地圖", systemImage: "map.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(
                        .roundedRectangle(radius: AppTheme.compactRadius)
                    )
                }

                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            .tint(AppTheme.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
        .accessibilityElement(children: .contain)
    }

    private var phoneURL: URL? {
        let normalized = clinic.phone.filter { $0.isNumber || $0 == "+" }
        guard !normalized.isEmpty else { return nil }
        return URL(string: "tel:\(normalized)")
    }

    private var mapsURL: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(
                name: "q",
                value: "\(clinic.institutionName) \(clinic.address)"
            )
        ]
        return components.url
    }

    private var formattedIssueDate: String? {
        let digits = clinic.issueDate.filter(\.isNumber)
        guard digits.count == 8 else {
            return clinic.issueDate.isEmpty ? nil : clinic.issueDate
        }
        return [
            String(digits.prefix(4)),
            String(digits.dropFirst(4).prefix(2)),
            String(digits.suffix(2))
        ].joined(separator: "-")
    }
}

// MARK: - List mode: slim row

private struct ClinicSlimRow: View {
    let clinic: VetClinic

    var body: some View {
        HStack(spacing: 10) {
            ClinicAvatar(name: clinic.name, size: 36, font: .subheadline)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(clinic.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if clinic.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.primary)
                            .accessibilityLabel("已審核刊登")
                    }
                }
                Text(clinic.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Label(String(format: "%.1f", clinic.avgRating), systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.warning)
                Text(clinic.priceLevelText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary)
            }

            Image(systemName: "chevron.forward")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .appCard()
    }
}

// MARK: - Grid mode: compact card

private struct ClinicGridCard: View {
    let clinic: VetClinic

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ClinicAvatar(name: clinic.name, size: 48, font: .title3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                if clinic.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primary)
                        .padding(4)
                        .accessibilityLabel("已審核刊登")
                }
            }

            Text(clinic.name)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.warning)
                Text(String(format: "%.1f", clinic.avgRating))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(clinic.priceLevelText)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

#Preview {
    ClinicListView()
}
