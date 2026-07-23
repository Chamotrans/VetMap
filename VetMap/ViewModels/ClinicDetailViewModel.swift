import Combine
import Foundation

@MainActor
@Observable
final class ClinicDetailViewModel {
    private(set) var reviews: [Review] = []
    private(set) var quotes: [Quote] = []
    private(set) var storageError: String?
    private(set) var isLoading = true

    private let clinic: VetClinic
    private let seedRepository: MockCommunityRepository
    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init(
        clinic: VetClinic,
        repository: MockCommunityRepository = MockCommunityRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.clinic = clinic
        self.seedRepository = repository
        self.firebase = firebase
        self.reviews = []
        self.quotes = []
        observeCommunityChanges()
        Task { await loadCommunityData() }
    }

    var visibleReviews: [Review] {
        let moderation = ModerationStore.shared
        return reviews.filter {
            !moderation.removedReviewIDs.contains($0.id)
                && !moderation.blockedUserIDs.contains($0.userId)
        }
    }

    var visibleQuotes: [Quote] {
        let moderation = ModerationStore.shared
        return quotes.filter {
            !moderation.removedQuoteIDs.contains($0.id)
                && !moderation.blockedUserIDs.contains($0.userId)
        }
    }

    func loadCommunityData() async {
        isLoading = true
        defer { isLoading = false }

        await ModerationStore.shared.refreshPublicState()
        let seedReviews: [Review] = []
        let seedQuotes: [Quote] = []

        do {
            let fetchedReviews = try await firebase.fetchReviews(for: clinic.id)
            let fetchedQuotes = try await firebase.fetchQuotes(for: clinic.id)
            let helpfulCounts = (try? await firebase.fetchReviewHelpfulCounts()) ?? [:]
            reviews = Self.merge(cloud: fetchedReviews, seeds: seedReviews).map { review in
                var review = review
                review.helpfulCount += helpfulCounts[review.id, default: 0]
                return review
            }
            quotes = Self.merge(cloud: fetchedQuotes, seeds: seedQuotes)
            storageError = nil
        } catch {
            reviews = seedReviews
            quotes = seedQuotes
            storageError = "雲端社群資料暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "ClinicDetail.loadCommunityData")
        }
        Analytics.clinicViewed(clinic.name)
    }

    func submitReviewForModeration(_ draft: ReviewDraft) async -> Bool {
        let title = trimmed(draft.title)
        let content = trimmed(draft.content)
        let treatmentType = trimmed(draft.treatmentType)

        guard (1...5).contains(draft.rating), !title.isEmpty, !content.isEmpty else {
            storageError = "請填寫評分、標題和內容。"
            return false
        }

        guard let user = AuthViewModel.shared.user, let uid = user.uid, !uid.isEmpty else {
            storageError = "請先登入後再提交評價。"
            return false
        }

        do {
            try ContentSafety.validate([title, content, treatmentType])
            let now = Date()
            let review = Review(
                id: "review-\(UUID().uuidString)",
                clinicId: clinic.id,
                userId: uid,
                userName: normalizedDisplayName(user.displayName),
                rating: draft.rating,
                title: title,
                content: content,
                treatmentType: treatmentType.isEmpty ? nil : treatmentType,
                cost: draft.cost,
                images: nil,
                createdAt: now,
                updatedAt: now,
                helpfulCount: 0
            )
            try await ModerationStore.shared.submitReview(review, clinicName: clinic.name)
            storageError = nil
            Haptics.success()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func addQuote(
        treatmentType: String,
        estimatedCost: Decimal,
        actualCost: Decimal?,
        currency: String,
        notes: String
    ) async -> Bool {
        let type = trimmed(treatmentType)
        let cleanNotes = trimmed(notes)

        guard !type.isEmpty, estimatedCost > 0 else {
            storageError = "請填寫治療類型和預估費用。"
            return false
        }
        guard let uid = AuthViewModel.shared.user?.uid, !uid.isEmpty else {
            storageError = "請先登入後再提交報價。"
            return false
        }

        do {
            try ContentSafety.validate([type, cleanNotes])
            let quote = Quote(
                id: "quote-\(UUID().uuidString)",
                clinicId: clinic.id,
                userId: uid,
                treatmentType: type,
                estimatedCost: estimatedCost,
                actualCost: actualCost,
                currency: currency,
                notes: cleanNotes,
                createdAt: Date()
            )
            try await ModerationStore.shared.submitQuote(quote, clinicName: clinic.name)
            storageError = nil
            Haptics.success()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func reportReview(_ review: Review, reason: String) async -> Bool {
        await report(
            type: .review,
            id: review.id,
            title: review.title,
            reason: reason
        )
    }

    func reportClinic(reason: String) async -> Bool {
        await report(
            type: .clinic,
            id: clinic.id,
            title: clinic.name,
            reason: reason
        )
    }

    func reportQuote(_ quote: Quote, reason: String) async -> Bool {
        await report(
            type: .quote,
            id: quote.id,
            title: quote.treatmentType,
            reason: reason
        )
    }

    func blockUser(_ userID: String) async -> Bool {
        do {
            try await ModerationStore.shared.blockUser(userID)
            storageError = nil
            Haptics.medium()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func markHelpful(_ reviewId: String) async {
        do {
            try await firebase.markReviewHelpful(reviewId: reviewId)
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                reviews[index].helpfulCount += 1
            }
            storageError = nil
            Haptics.medium()
        } catch {
            storageError = error.localizedDescription
            CrashReporting.recordError(error, domain: "ClinicDetail.markHelpful")
        }
    }

    private func report(
        type: ReportTargetType,
        id: String,
        title: String,
        reason: String
    ) async -> Bool {
        do {
            try await ModerationStore.shared.submitReport(
                targetType: type,
                targetId: id,
                targetTitle: title,
                clinicId: clinic.id,
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

    private func normalizedDisplayName(_ value: String?) -> String {
        let name = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "VetMap 用戶" : name
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func observeCommunityChanges() {
        NotificationCenter.default.publisher(for: .vetCommunityRepositoryDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .vetModerationDidChange))
            .sink { [weak self] notification in
                let clinicID = notification.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String
                Task { @MainActor in
                    guard let self, clinicID == nil || clinicID == self.clinic.id else { return }
                    await self.loadCommunityData()
                }
            }
            .store(in: &cancellables)
    }

    private static func merge<T: Identifiable>(
        cloud: [T],
        seeds: [T]
    ) -> [T] where T.ID: Hashable {
        let cloudIDs = Set(cloud.map(\.id))
        return cloud + seeds.filter { !cloudIDs.contains($0.id) }
    }
}
