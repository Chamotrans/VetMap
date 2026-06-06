import Foundation

protocol CommunityRepositoryProtocol {
    func fetchReviews(for clinicId: String) async throws -> [Review]
    func addReview(_ review: Review) async throws
    func fetchQuotes(for clinicId: String) async throws -> [Quote]
    func addQuote(_ quote: Quote) async throws
}

struct CommunityRepository: CommunityRepositoryProtocol {
    #if canImport(Firebase)
    private let firebaseService: FirebaseService?
    #endif
    private let localRepository: MockCommunityRepository

    init(localRepository: MockCommunityRepository = MockCommunityRepository()) {
        #if canImport(Firebase)
        self.firebaseService = FirebaseService.shared
        #else
        #endif
        self.localRepository = localRepository
    }

    // MARK: - Reviews

    func fetchReviews(for clinicId: String) async throws -> [Review] {
        #if canImport(Firebase)
        if let firebaseService {
            do {
                return try await firebaseService.fetchReviews(for: clinicId)
            } catch {
                return localRepository.fetchReviews(for: clinicId)
            }
        }
        #endif
        return localRepository.fetchReviews(for: clinicId)
    }

    func addReview(_ review: Review) async throws {
        #if canImport(Firebase)
        if let firebaseService {
            var firebaseFailed = false
            do {
                try await firebaseService.addReview(review)
            } catch {
                firebaseFailed = true
            }
            try localRepository.addReview(review)
            if firebaseFailed {
                throw FirebaseError.notConfigured
            }
            return
        }
        #endif
        try localRepository.addReview(review)
    }

    // MARK: - Quotes

    func fetchQuotes(for clinicId: String) async throws -> [Quote] {
        #if canImport(Firebase)
        if let firebaseService {
            do {
                return try await firebaseService.fetchQuotes(for: clinicId)
            } catch {
                return localFallbackQuotes(for: clinicId)
            }
        }
        #endif
        return localFallbackQuotes(for: clinicId)
    }

    func addQuote(_ quote: Quote) async throws {
        #if canImport(Firebase)
        if let firebaseService {
            var firebaseFailed = false
            do {
                try await firebaseService.addQuote(quote)
            } catch {
                firebaseFailed = true
            }
            writeQuoteLocally(quote)
            postQuoteNotification(quote)
            if firebaseFailed {
                throw FirebaseError.notConfigured
            }
            return
        }
        #endif
        writeQuoteLocally(quote)
        postQuoteNotification(quote)
    }

    // MARK: - Private helpers

    private func localFallbackQuotes(for clinicId: String) -> [Quote] {
        let seedQuotes = localRepository.fetchQuotes(for: clinicId)
        let userQuotes = Self.quotesQueue.sync {
            Self.userQuotes
                .filter { $0.clinicId == clinicId }
                .sorted { $0.createdAt > $1.createdAt }
        }
        let seen = Set(userQuotes.map(\.id))
        return userQuotes + seedQuotes.filter { !seen.contains($0.id) }
    }

    private func writeQuoteLocally(_ quote: Quote) {
        Self.quotesQueue.sync {
            if let index = Self.userQuotes.firstIndex(where: { $0.id == quote.id }) {
                Self.userQuotes[index] = quote
            } else {
                Self.userQuotes.append(quote)
            }
        }
    }

    private func postQuoteNotification(_ quote: Quote) {
        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [MockCommunityRepository.changedClinicIDUserInfoKey: quote.clinicId]
        )
    }

    private static let quotesQueue = DispatchQueue(label: "com.vetmap.quotes")
    private static var userQuotes: [Quote] = []
}
