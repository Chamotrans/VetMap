import Combine
import Foundation

@MainActor
final class QuoteViewModel: ObservableObject {
    @Published private(set) var quotes: [Quote] = []
    @Published private(set) var storageError: String?

    private let clinicId: String
    private let repository: MockCommunityRepository
    private var cancellables: Set<AnyCancellable> = []

    init(
        clinicId: String,
        repository: MockCommunityRepository = MockCommunityRepository()
    ) {
        self.clinicId = clinicId
        self.repository = repository
        observeCommunityChanges()
        loadQuotes()
    }

    func loadQuotes() {
        quotes = repository.fetchQuotes(for: clinicId)
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
            clinicId: clinicId,
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
            loadQuotes()
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
                    guard let self, clinicID == nil || clinicID == self.clinicId else { return }
                    self.loadQuotes()
                }
            }
            .store(in: &cancellables)
    }
}
