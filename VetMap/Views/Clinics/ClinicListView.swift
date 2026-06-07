import SwiftUI

struct ClinicListView: View {
    @StateObject private var viewModel = ClinicsViewModel()
    @State private var clinicForDetail: VetClinic?
    @State private var isAddingClinic = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            ipadLayout
        } else {
            iphoneLayout
        }
    }

    private var iphoneLayout: some View {
        NavigationStack {
            clinicListContent
                .navigationTitle("獸醫診所 (\(MockClinicRepository().fetchClinics().count))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.filter.query, prompt: "搜尋診所、地區、服務")
            .onSubmit(of: .search) { Analytics.searchPerformed(viewModel.filter.query) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isAddingClinic = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增診所")
                    }
                }
                .sheet(item: $clinicForDetail) { clinic in
                    ClinicDetailView(clinic: clinic)
                }
                .sheet(isPresented: $isAddingClinic) {
                    AddClinicView { clinic in
                        viewModel.addClinic(clinic)
                    }
                }
        }
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            clinicListContent
                .navigationTitle("獸醫診所 (\(MockClinicRepository().fetchClinics().count))")
                .navigationBarTitleDisplayMode(.large)
                .searchable(text: $viewModel.filter.query, prompt: "搜尋診所、地區、服務")
            .onSubmit(of: .search) { Analytics.searchPerformed(viewModel.filter.query) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isAddingClinic = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("新增診所")
                    }
                }
                .sheet(isPresented: $isAddingClinic) {
                    AddClinicView { clinic in
                        viewModel.addClinic(clinic)
                    }
                }
        } detail: {
            if let clinic = clinicForDetail {
                NavigationStack {
                    ClinicDetailView(clinic: clinic)
                }
            } else {
                ContentUnavailableView(
                    "選擇診所",
                    systemImage: "cross.case",
                    description: Text("從列表中選擇一間診所以查看詳情")
                )
            }
        }
    }

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

            Text("資料來源：ePetPet HK + petcircle • 共 222 間診所")

            Text("最近更新：2026年6月")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
        }
        .refreshable {
            viewModel.retryLoad()
        }
        .background(AppTheme.screenBackground)
        .onAppear {
            viewModel.loadClinics()
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

                Text("已驗證資料優先顯示，新增後會保存在本機。")
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
        if viewModel.filter.isActive {
            return "\(viewModel.filteredClinics.count) / \(viewModel.clinics.count) 間診所"
        }

        return "\(viewModel.filteredClinics.count) 間診所"
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

    @ViewBuilder
    private var clinicRows: some View {
        if viewModel.clinics.isEmpty && !viewModel.isLoading {
            dataMissingView
        } else if viewModel.filteredClinics.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.filteredClinics) { clinic in
                    Button {
                        clinicForDetail = clinic
                    } label: {
                        ClinicListRowView(clinic: clinic)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(clinic.name), 評分 \(String(format: "%.1f", clinic.avgRating))")
                    .accessibilityHint("開啟診所詳情")
                }
            }
            .animation(.default, value: viewModel.filteredClinics)
        }
    }

    private var dataMissingView: some View {
        ErrorRetryView(
            icon: "exclamationmark.triangle.fill",
            title: "無法載入診所資料",
            message: "請檢查網絡連線後重試。",
            retryLabel: "重試",
            onRetry: { viewModel.retryLoad() }
        )
        .padding(.top, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
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
}

#Preview {
    ClinicListView()
}
