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

private enum ClinicSubmissionError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message): message
        }
    }
}

struct ClinicListView: View {
    @State private var viewModel = ClinicsViewModel()
    @State private var clinicForDetail: VetClinic?
    @State private var isAddingClinic = false
    @AppStorage("clinicViewMode") private var rawViewMode = ClinicBrowseMode.detail.rawValue
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var viewMode: ClinicBrowseMode {
        ClinicBrowseMode(rawValue: rawViewMode) ?? .detail
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
                .navigationTitle("獸醫診所 (\(viewModel.filteredClinics.count))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.filter.query, prompt: "搜尋診所、地區、服務")
                .onSubmit(of: .search) { Analytics.searchPerformed(viewModel.filter.query) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rawViewMode = viewMode.next.rawValue
                            }
                        } label: {
                            Image(systemName: viewMode.next.icon)
                        }
                        .accessibilityLabel("切換為\(viewMode.next.label)模式")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isAddingClinic = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增診所")
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Button { isAddingClinic = true } label: {
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
        }
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            clinicListContent
                .navigationTitle("獸醫診所 (\(viewModel.filteredClinics.count))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.filter.query, prompt: "搜尋診所、地區、服務")
                .onSubmit(of: .search) { Analytics.searchPerformed(viewModel.filter.query) }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                rawViewMode = viewMode.next.rawValue
                            }
                        } label: {
                            Image(systemName: viewMode.next.icon)
                        }
                        .accessibilityLabel("切換為\(viewMode.next.label)模式")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { isAddingClinic = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增診所")
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
                header
                filterBar
                storageErrorBanner
                resultsSummary
                clinicRows
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)

            Text("資料由社群投稿，經管理員審核後公開")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .refreshable { await viewModel.retryLoad() }
        .organicBackground()
        .onAppear {
            Task {
                await viewModel.loadClinics()
                if AppLaunchFlags.autoPresentClinic, clinicForDetail == nil {
                    clinicForDetail = viewModel.filteredClinics.first
                }
            }
        }
    }

    // MARK: - Subviews

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
            action: ("新增診所", { isAddingClinic = true })
        )
        .padding(.top, 20)
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
