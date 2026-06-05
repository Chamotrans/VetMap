import Combine
import Foundation

@MainActor
final class ClinicDetailViewModel: ObservableObject {
    @Published private(set) var reviews: [Review] = []
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var storageError: String?
    @Published private(set) var isLoading = true

    private let clinic: VetClinic
    private let repository: MockCommunityRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        clinic: VetClinic,
        repository: MockCommunityRepository = MockCommunityRepository()
    ) {
        self.clinic = clinic
        self.repository = repository
        observeCommunityChanges()
        loadCommunityData()
        isLoading = false
    }

    func loadCommunityData() {
        reviews = repository.fetchReviews(for: clinic.id)
        quotes = repository.fetchQuotes(for: clinic.id)
    }

    func markHelpful(_ reviewId: String) {
        guard let original = reviews.first(where: { $0.id == reviewId }) else { return }

        var updated = original
        updated.helpfulCount += 1

        do {
            try repository.addReview(updated)
            loadCommunityData()
            Haptics.medium()
        } catch {
            if let index = reviews.firstIndex(where: { $0.id == reviewId }) {
                reviews[index].helpfulCount += 1
            }
        }
    }

    func addReview(_ draft: ReviewDraft) -> Bool {
        let title = trimmed(draft.title)
        let content = trimmed(draft.content)
        let treatmentType = trimmed(draft.treatmentType)

        guard (1...5).contains(draft.rating), !title.isEmpty, !content.isEmpty else {
            storageError = "請填寫評分、標題和內容。"
            return false
        }

        let now = Date()
        let review = Review(
            id: "review-\(UUID().uuidString)",
            clinicId: clinic.id,
            userId: "local-user",
            userName: "本機用戶",
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

        do {
            try repository.addReview(review)
            storageError = nil
            loadCommunityData()
            Haptics.success()
        } catch {
            storageError = "評價已加入目前畫面，但暫時無法儲存到本機。"
            reviews.insert(review, at: 0)
        }

        return true
    }

    func addQuote(
        treatmentType: String,
        estimatedCost: Decimal,
        actualCost: Decimal?,
        currency: String,
        notes: String
    ) -> Bool {
        let trimmedType = trimmed(treatmentType)
        let trimmedNotes = trimmed(notes)

        guard !trimmedType.isEmpty, estimatedCost > 0 else {
            storageError = "請填寫治療類型和預估費用。"
            return false
        }

        let quote = Quote(
            id: "quote-\(UUID().uuidString)",
            clinicId: clinic.id,
            userId: "local-user",
            treatmentType: trimmedType,
            estimatedCost: estimatedCost,
            actualCost: actualCost,
            currency: currency,
            notes: trimmedNotes,
            createdAt: Date()
        )

        do {
            try repository.addQuote(quote)
            storageError = nil
            loadCommunityData()
        } catch {
            storageError = "報價已加入目前畫面，但暫時無法儲存到本機。"
            quotes.insert(quote, at: 0)
        }

        return true
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func observeCommunityChanges() {
        NotificationCenter.default.publisher(for: .vetCommunityRepositoryDidChange)
            .sink { [weak self] notification in
                let clinicID = notification.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String

                Task { @MainActor in
                    guard let self, clinicID == nil || clinicID == self.clinic.id else { return }
                    self.loadCommunityData()
                }
            }
            .store(in: &cancellables)
    }
}
