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
    private let firebase: FirebaseService?
    @ObservationIgnored private let authenticatedUIDProvider: () -> String?
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var usesTestingFixtures = false
    @ObservationIgnored private var testingChangeHandler: (() -> Void)?

    init(
        clinicId: String,
        clinicName: String = "",
        repository: MockCommunityRepository = MockCommunityRepository(),
        firebase: FirebaseService = .shared,
        authenticatedUIDProvider: (() -> String?)? = nil
    ) {
        self.clinicId = clinicId
        self.clinicName = clinicName
        self.seedRepository = repository
        self.firebase = firebase
        self.authenticatedUIDProvider = authenticatedUIDProvider ?? { AuthViewModel.shared.user?.uid }
        self.quotes = []
        observeCommunityChanges()
        Task { await loadQuotes() }
    }

    /// Non-observing fixture initializer for deterministic unit tests.
    init(
        testingQuotes: [Quote],
        clinicId: String,
        clinicName: String = "",
        observesChanges: Bool = false,
        testingChangeHandler: (() -> Void)? = nil,
        authenticatedUIDProvider: @escaping () -> String? = { nil }
    ) {
        self.clinicId = clinicId
        self.clinicName = clinicName
        self.seedRepository = MockCommunityRepository()
        self.firebase = nil
        self.authenticatedUIDProvider = authenticatedUIDProvider
        self.quotes = testingQuotes
        self.usesTestingFixtures = true
        self.testingChangeHandler = testingChangeHandler
        if observesChanges {
            observeCommunityChanges()
        }
    }

    var visibleQuotes: [Quote] {
        if usesTestingFixtures {
            return quotes
        }
        let moderation = ModerationStore.shared
        return quotes.filter {
            !moderation.removedQuoteIDs.contains($0.id)
                && !moderation.blockedUserIDs.contains($0.userId)
        }
    }

    func loadQuotes() async {
        isLoading = true
        defer { isLoading = false }
        guard let firebase else { return }

        let seeds: [Quote] = []
        await ModerationStore.shared.refreshPublicState()
        do {
            let cloud = try await firebase.fetchQuotes(for: clinicId)
            let cloudIDs = Set(cloud.map(\.id))
            let refreshedQuotes = cloud + seeds.filter { !cloudIDs.contains($0.id) }
            quotes = refreshedQuotes
            storageError = nil
        } catch {
            storageError = "雲端報價暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "QuoteViewModel.loadQuotes")
        }
    }

    func addQuote(_ draft: QuoteDraft) async -> CommunitySubmissionResult {
        let type = trimmed(draft.treatmentType)
        let cleanNotes = trimmed(draft.notes)

        guard !type.isEmpty, draft.estimatedCost > 0 else {
            storageError = "請填寫治療類型和預估費用。"
            return .failed(
                message: storageError ?? String(localized: "暫時無法提交報價。")
            )
        }
        guard let uid = authenticatedUIDProvider(), !uid.isEmpty else {
            storageError = String(localized: "請先登入後再提交報價。")
            return .authenticationRequired
        }

        do {
            try ContentSafety.validate([type, cleanNotes])
            let quote = Quote(
                id: "quote-\(UUID().uuidString)",
                clinicId: clinicId,
                userId: uid,
                treatmentType: type,
                estimatedCost: draft.estimatedCost,
                actualCost: draft.actualCost,
                currency: draft.currency,
                notes: cleanNotes,
                createdAt: Date()
            )
            try await ModerationStore.shared.submitQuote(
                quote,
                clinicName: clinicName.isEmpty ? clinicId : clinicName
            )
            storageError = nil
            Haptics.success()
            return .submitted
        } catch FirebaseError.authenticationRequired {
            storageError = String(localized: "請先登入後再提交報價。")
            return .authenticationRequired
        } catch {
            storageError = error.localizedDescription
            return .failed(message: error.localizedDescription)
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
                    if let testingChangeHandler = self.testingChangeHandler {
                        testingChangeHandler()
                        return
                    }
                    await self.loadQuotes()
                }
            }
            .store(in: &cancellables)
    }
}
