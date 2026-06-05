import Combine
import Foundation

enum ReviewSortOrder: String, CaseIterable {
    case newest = "最新"
    case highestRating = "最高評分"
    case mostHelpful = "最多有用"
}

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var reviews: [Review] = []
    @Published var sortOrder: ReviewSortOrder = .newest

    private let clinicId: String
    private let repository: MockCommunityRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        clinicId: String,
        repository: MockCommunityRepository = MockCommunityRepository()
    ) {
        self.clinicId = clinicId
        self.repository = repository
        observeRepositoryChanges()
        loadReviews()
    }

    var sortedReviews: [Review] {
        switch sortOrder {
        case .newest:
            reviews.sorted { $0.createdAt > $1.createdAt }
        case .highestRating:
            reviews.sorted { $0.rating > $1.rating }
        case .mostHelpful:
            reviews.sorted { $0.helpfulCount > $1.helpfulCount }
        }
    }

    func loadReviews() {
        reviews = repository.fetchReviews(for: clinicId)
    }

    func markHelpful(_ reviewId: String) {
        guard let index = reviews.firstIndex(where: { $0.id == reviewId }) else { return }

        var updated = reviews[index]
        updated.helpfulCount += 1

        // Update in-memory immediately
        reviews[index] = updated

        // Persist (best-effort)
        do {
            try repository.addReview(updated)
        } catch {
            // In-memory update already applied, persistence can retry later
        }
    }

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetCommunityRepositoryDidChange)
            .sink { [weak self] notification in
                let changedID = notification.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String

                Task { @MainActor in
                    guard let self, changedID == nil || changedID == self.clinicId else { return }
                    self.loadReviews()
                }
            }
            .store(in: &cancellables)
    }
}
