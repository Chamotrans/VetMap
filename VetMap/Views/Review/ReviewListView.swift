import SwiftUI

struct ReviewListView: View {
    let clinic: VetClinic

    @State private var viewModel: ReviewViewModel

    init(clinic: VetClinic) {
        self.clinic = clinic
        _viewModel = State(wrappedValue: ReviewViewModel(clinicId: clinic.id))
    }

    private var currency: String {
        clinic.address.localizedCaseInsensitiveContains("香港") ? "HKD" : "TWD"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sortPicker

                if let error = viewModel.storageError {
                    Label(error, systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard(
                            fill: AppTheme.warning.opacity(0.12),
                            stroke: AppTheme.warning.opacity(0.22)
                        )
                }

                if viewModel.sortedReviews.isEmpty {
                    emptyState
                } else {
                    reviewCountSummary

                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.sortedReviews) { review in
                            ReviewRowView(
                                review: review,
                                currency: currency,
                                onMarkHelpful: {
                                    Task { await viewModel.markHelpful(review.id) }
                                },
                                onReport: { reason in
                                    Task { _ = await viewModel.report(review, reason: reason) }
                                },
                                onBlockAuthor: {
                                    Task { _ = await viewModel.blockAuthor(of: review) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground)
        .refreshable {
            await viewModel.loadReviews()
        }
        .navigationTitle("\(clinic.name) 評價")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("排序方式")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("排序", selection: $viewModel.sortOrder) {
                ForEach(ReviewSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .appCard()
    }

    private var reviewCountSummary: some View {
        HStack {
            Label("共 \(viewModel.sortedReviews.count) 則評價", systemImage: "text.bubble.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.title)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 56, height: 56)
                .background(
                    AppTheme.primary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )

            Text("暫無評價")
                .font(.headline)

            Text("成為第一位分享經驗的寵物主人")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

#Preview {
    NavigationStack {
        ReviewListView(clinic: MockClinicRepository.hkClinics[0])
    }
}
