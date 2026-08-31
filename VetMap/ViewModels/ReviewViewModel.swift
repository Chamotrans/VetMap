import Combine
import Foundation

enum ReviewSortOrder: String, CaseIterable {
    case newest = "最新"
    case highestRating = "最高評分"
    case mostHelpful = "最多有用"
}

@MainActor
@Observable
final class ReviewViewModel {
    private(set) var reviews: [Review] = []
    var sortOrder: ReviewSortOrder = .newest
    private(set) var storageError: String?
    private(set) var isLoading = false

    private let clinicId: String
    private let seedRepository: MockCommunityRepository
    private let firebase: FirebaseService?
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var usesTestingFixtures = false
    @ObservationIgnored private var testingChangeHandler: (() -> Void)?
    @ObservationIgnored private var testingNotificationHandler: (() -> Void)?
    @ObservationIgnored private var testingMarkHelpfulHandler: ((String) -> Void)?

    init(
        clinicId: String,
        repository: MockCommunityRepository = MockCommunityRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.clinicId = clinicId
        self.seedRepository = repository
        self.firebase = firebase
        self.reviews = []
        observeRepositoryChanges()
        Task { await loadReviews() }
    }

    /// Non-observing fixture initializer for deterministic unit tests.
    init(
        testingReviews: [Review],
        clinicId: String,
        observesChanges: Bool = false,
        testingChangeHandler: (() -> Void)? = nil,
        testingNotificationHandler: (() -> Void)? = nil,
        testingMarkHelpfulHandler: @escaping (String) -> Void = { _ in }
    ) {
        self.clinicId = clinicId
        self.seedRepository = MockCommunityRepository()
        self.firebase = nil
        self.reviews = testingReviews
        self.usesTestingFixtures = true
        self.testingChangeHandler = testingChangeHandler
        self.testingNotificationHandler = testingNotificationHandler
        self.testingMarkHelpfulHandler = testingMarkHelpfulHandler
        if observesChanges {
            observeRepositoryChanges()
        }
    }

    var sortedReviews: [Review] {
        let visible: [Review]
        if usesTestingFixtures {
            visible = reviews
        } else {
            let moderation = ModerationStore.shared
            visible = reviews.filter {
                !moderation.removedReviewIDs.contains($0.id)
                    && !moderation.blockedUserIDs.contains($0.userId)
            }
        }
        return switch sortOrder {
        case .newest:
            visible.sorted { $0.createdAt > $1.createdAt }
        case .highestRating:
            visible.sorted { $0.rating > $1.rating }
        case .mostHelpful:
            visible.sorted { $0.helpfulCount > $1.helpfulCount }
        }
    }

    func loadReviews() async {
        isLoading = true
        defer { isLoading = false }
        guard let firebase else { return }
        let seeds: [Review] = []
        await ModerationStore.shared.refreshPublicState()

        do {
            let cloud = try await firebase.fetchReviews(for: clinicId)
            let cloudIDs = Set(cloud.map(\.id))
            let helpfulCounts = try? await firebase.fetchReviewHelpfulCounts()
            let displayedHelpfulCounts = reviews.reduce(into: [String: Int]()) { counts, review in
                counts[review.id] = review.helpfulCount
            }
            let refreshedReviews = (cloud + seeds.filter { !cloudIDs.contains($0.id) }).map { review in
                var review = review
                if let helpfulCounts {
                    review.helpfulCount += helpfulCounts[review.id, default: 0]
                } else if let displayedHelpfulCount = displayedHelpfulCounts[review.id] {
                    review.helpfulCount = displayedHelpfulCount
                }
                return review
            }
            reviews = refreshedReviews
            storageError = nil
        } catch {
            storageError = "雲端評價暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "ReviewViewModel.loadReviews")
        }
    }

    func markHelpful(_ reviewId: String) async {
        if let testingMarkHelpfulHandler {
            testingMarkHelpfulHandler(reviewId)
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                reviews[index].helpfulCount += 1
            }
            storageError = nil
            return
        }

        guard let firebase else { return }
        do {
            try await firebase.markReviewHelpful(reviewId: reviewId)
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                reviews[index].helpfulCount += 1
            }
            storageError = nil
        } catch {
            storageError = error.localizedDescription
            CrashReporting.recordError(error, domain: "ReviewViewModel.markHelpful")
        }
    }

    func report(_ review: Review, reason: String) async -> Bool {
        do {
            try await ModerationStore.shared.submitReport(
                targetType: .review,
                targetId: review.id,
                targetTitle: review.title,
                clinicId: clinicId,
                reason: reason
            )
            storageError = nil
            Haptics.medium()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func blockAuthor(of review: Review) async -> Bool {
        do {
            try await ModerationStore.shared.blockUser(review.userId)
            storageError = nil
            Haptics.medium()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetCommunityRepositoryDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .vetModerationDidChange))
            .sink { [weak self] notification in
                let changedID = notification.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String
                Task { @MainActor in
                    guard let self else { return }
                    self.testingNotificationHandler?()
                    guard changedID == nil || changedID == self.clinicId else { return }
                    if let testingChangeHandler = self.testingChangeHandler {
                        testingChangeHandler()
                        return
                    }
                    await self.loadReviews()
                }
            }
            .store(in: &cancellables)
    }
}
