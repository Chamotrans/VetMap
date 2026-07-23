import Foundation

/// Local persistence used by tests and legacy on-device drafts.
///
/// Release builds contain no bundled reviews or quotes. Public community
/// content comes only from Firestore after admin approval, under the
/// contributor licence in the Terms of Service.
struct MockCommunityRepository {
    private let localReviewsFileURL: URL
    private let localQuotesFileURL: URL
    private let fileManager: FileManager

    init(
        localReviewsFileURL: URL = Self.defaultLocalReviewsFileURL(),
        localQuotesFileURL: URL = Self.defaultLocalQuotesFileURL(),
        fileManager: FileManager = .default
    ) {
        self.localReviewsFileURL = localReviewsFileURL
        self.localQuotesFileURL = localQuotesFileURL
        self.fileManager = fileManager
    }

    func fetchReviews(for clinicID: String) -> [Review] {
        fetchLocalReviews()
            .filter { $0.clinicId == clinicID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchQuotes(for clinicID: String) -> [Quote] {
        fetchLocalQuotes()
            .filter { $0.clinicId == clinicID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func findReview(id: String) -> Review? {
        fetchLocalReviews().first { $0.id == id }
    }

    func findQuote(id: String) -> Quote? {
        fetchLocalQuotes().first { $0.id == id }
    }

    func addQuote(_ quote: Quote) throws {
        var localQuotes = fetchLocalQuotes()

        if let existingIndex = localQuotes.firstIndex(where: { $0.id == quote.id }) {
            localQuotes[existingIndex] = quote
        } else {
            localQuotes.append(quote)
        }

        try saveLocalQuotes(localQuotes)
        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [Self.changedClinicIDUserInfoKey: quote.clinicId]
        )
    }

    func fetchLocalQuotes() -> [Quote] {
        guard fileManager.fileExists(atPath: localQuotesFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: localQuotesFileURL)
            return try Self.decoder.decode([Quote].self, from: data)
        } catch {
            return []
        }
    }

    private func saveLocalQuotes(_ quotes: [Quote]) throws {
        let directory = localQuotesFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try Self.encoder.encode(quotes)
        try data.write(to: localQuotesFileURL, options: [.atomic])
    }

    func addReview(_ review: Review) throws {
        var localReviews = fetchLocalReviews()

        if let existingIndex = localReviews.firstIndex(where: { $0.id == review.id }) {
            localReviews[existingIndex] = review
        } else {
            localReviews.append(review)
        }

        try saveLocalReviews(localReviews)
        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [Self.changedClinicIDUserInfoKey: review.clinicId]
        )
    }

    func fetchLocalReviews() -> [Review] {
        guard fileManager.fileExists(atPath: localReviewsFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: localReviewsFileURL)
            return try Self.decoder.decode([Review].self, from: data)
        } catch {
            return []
        }
    }

    private func saveLocalReviews(_ reviews: [Review]) throws {
        let directory = localReviewsFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try Self.encoder.encode(reviews)
        try data.write(to: localReviewsFileURL, options: [.atomic])
    }

    private static func defaultLocalReviewsFileURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "VetMap", directoryHint: .isDirectory)
            .appending(path: "reviews.json")
    }

    private static func defaultLocalQuotesFileURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "VetMap", directoryHint: .isDirectory)
            .appending(path: "quotes.json")
    }

    static let changedClinicIDUserInfoKey = "changedClinicID"
    static let seedReviews: [Review] = []
    static let seedQuotes: [Quote] = []

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Notification.Name {
    static let vetCommunityRepositoryDidChange = Notification.Name("vetCommunityRepositoryDidChange")
}
