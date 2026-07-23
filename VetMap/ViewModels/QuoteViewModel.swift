import Combine
import Foundation

@MainActor
@Observable
final class QuoteViewModel {
    private(set) var quotes: [Quote] = []
    private(set) var storageError: String?
    private(set) var isLoading = false

    private let clinicId: String
    private let clinicName: String
    private let seedRepository: MockCommunityRepository
    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init(
        clinicId: String,
        clinicName: String = "",
        repository: MockCommunityRepository = MockCommunityRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.clinicId = clinicId
        self.clinicName = clinicName
        self.seedRepository = repository
        self.firebase = firebase
        self.quotes = []
        observeCommunityChanges()
        Task { await loadQuotes() }
    }

    var visibleQuotes: [Quote] {
        let moderation = ModerationStore.shared
        return quotes.filter {
            !moderation.removedQuoteIDs.contains($0.id)
                && !moderation.blockedUserIDs.contains($0.userId)
        }
    }

    func loadQuotes() async {
        isLoading = true
        defer { isLoading = false }

        let seeds: [Quote] = []
        await ModerationStore.shared.refreshPublicState()
        do {
            let cloud = try await firebase.fetchQuotes(for: clinicId)
            let cloudIDs = Set(cloud.map(\.id))
            quotes = cloud + seeds.filter { !cloudIDs.contains($0.id) }
            storageError = nil
        } catch {
            quotes = seeds
            storageError = "雲端報價暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "QuoteViewModel.loadQuotes")
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
                clinicId: clinicId,
                userId: uid,
                treatmentType: type,
                estimatedCost: estimatedCost,
                actualCost: actualCost,
                currency: currency,
                notes: cleanNotes,
                createdAt: Date()
            )
            try await ModerationStore.shared.submitQuote(
                quote,
                clinicName: clinicName.isEmpty ? clinicId : clinicName
            )
            storageError = nil
            Haptics.success()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    func report(_ quote: Quote, reason: String) async -> Bool {
        do {
            try await ModerationStore.shared.submitReport(
                targetType: .quote,
                targetId: quote.id,
                targetTitle: quote.treatmentType,
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

    func blockAuthor(of quote: Quote) async -> Bool {
        do {
            try await ModerationStore.shared.blockUser(quote.userId)
            storageError = nil
            Haptics.medium()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
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
                    guard let self, clinicID == nil || clinicID == self.clinicId else { return }
                    await self.loadQuotes()
                }
            }
            .store(in: &cancellables)
    }
}
