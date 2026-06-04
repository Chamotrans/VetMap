import SwiftUI

struct ClinicListView: View {
    @StateObject private var viewModel = ClinicsViewModel()
    @State private var clinicForDetail: VetClinic?
    @State private var isAddingClinic = false

    var body: some View {
        NavigationStack {
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
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("獸醫診所")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "搜尋診所、地區、服務")
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
            .onAppear {
                viewModel.loadClinics()
            }
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
        Picker("篩選", selection: $viewModel.selectedFilter) {
            ForEach(ClinicsViewModel.Filter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(2)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        .accessibilityLabel("診所篩選")
    }

    private var resultsSummary: some View {
        HStack {
            Text("\(viewModel.filteredClinics.count) 間診所")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text("依驗證與評分排序")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
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
        if viewModel.filteredClinics.isEmpty {
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
                    .accessibilityHint("開啟診所詳情")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 56, height: 56)
                .background(AppTheme.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .accessibilityHidden(true)

            Text("找不到符合條件的診所")
                .font(.headline)

            Text("試試放寬篩選，或改用地區、服務項目搜尋。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

#Preview {
    ClinicListView()
}
