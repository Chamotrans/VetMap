import Foundation

// MARK: - ⚠️ DUMMY SEED DATA — 僅供開發測試用，上線前需替換為真實資料
// 所有 static let reviews / quotes 內的評論與報價資料皆為虛構，
// 僅用於開發與測試。上線前請替換為 Firebase 或其他真實資料來源。

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
        let localReviews = fetchLocalReviews()
        let localIDs = Set(localReviews.map(\.id))
        // Local reviews override seed reviews with the same ID
        let merged = Self.reviews.filter { !localIDs.contains($0.id) } + localReviews
        return merged
            .filter { $0.clinicId == clinicID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchQuotes(for clinicID: String) -> [Quote] {
        (Self.quotes + fetchLocalQuotes())
            .filter { $0.clinicId == clinicID }
            .sorted { $0.createdAt > $1.createdAt }
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

    static let reviews: [Review] = [
        Review(
            id: "review-taipei-anxin-1",
            clinicId: "taipei-anxin",
            userId: "seed-user-1",
            userName: "Ming",
            rating: 5,
            title: "收費講得好清楚",
            content: "打疫苗前會先列明費用，醫生亦有解釋術前注意事項，整體很安心。",
            treatmentType: "疫苗",
            cost: Decimal(800),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_260_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_260_000),
            helpfulCount: 12
        ),
        Review(
            id: "review-taipei-anxin-2",
            clinicId: "taipei-anxin",
            userId: "seed-user-2",
            userName: "Yuki",
            rating: 5,
            title: "對貓很溫柔",
            content: "診間不會催促，護理師會慢慢安撫貓咪，回家後追蹤也很仔細。",
            treatmentType: "一般診療",
            cost: Decimal(1200),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_180_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_180_000),
            helpfulCount: 8
        ),
        Review(
            id: "review-taipei-greenpaw-1",
            clinicId: "taipei-greenpaw",
            userId: "seed-user-3",
            userName: "Chloe",
            rating: 4,
            title: "設備完整但偏貴",
            content: "影像檢查安排很順，報告解釋清楚；價格較高，適合需要專科意見時去。",
            treatmentType: "影像檢查",
            cost: Decimal(4200),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_090_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_090_000),
            helpfulCount: 6
        ),
        Review(
            id: "review-hk-harbour-1",
            clinicId: "hk-harbour",
            userId: "seed-user-4",
            userName: "Sunny",
            rating: 5,
            title: "夜診幫到手",
            content: "晚上臨時腸胃不適都有位，職員會先講大概收費，英文溝通也順。",
            treatmentType: "夜間門診",
            cost: Decimal(980),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_320_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_320_000),
            helpfulCount: 15
        ),
        Review(
            id: "review-hk-kowloon-care-1",
            clinicId: "hk-kowloon-care",
            userId: "seed-user-5",
            userName: "Hei",
            rating: 4,
            title: "初診流程清楚",
            content: "第一次帶狗狗去，前台解釋流程清楚，等候時間可接受。",
            treatmentType: "初診",
            cost: Decimal(620),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1_718_210_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_210_000),
            helpfulCount: 5
        )
    ]

    static let quotes: [Quote] = [
        Quote(
            id: "quote-taipei-anxin-vaccine",
            clinicId: "taipei-anxin",
            userId: "seed-user-1",
            treatmentType: "疫苗",
            estimatedCost: Decimal(800),
            actualCost: Decimal(800),
            currency: "TWD",
            notes: "含基本觸診。",
            createdAt: Date(timeIntervalSince1970: 1_718_260_000)
        ),
        Quote(
            id: "quote-taipei-greenpaw-image",
            clinicId: "taipei-greenpaw",
            userId: "seed-user-3",
            treatmentType: "影像檢查",
            estimatedCost: Decimal(4000),
            actualCost: Decimal(4200),
            currency: "TWD",
            notes: "依檢查項目浮動。",
            createdAt: Date(timeIntervalSince1970: 1_718_090_000)
        ),
        Quote(
            id: "quote-hk-harbour-night",
            clinicId: "hk-harbour",
            userId: "seed-user-4",
            treatmentType: "夜間門診",
            estimatedCost: Decimal(900),
            actualCost: Decimal(980),
            currency: "HKD",
            notes: "未含藥費。",
            createdAt: Date(timeIntervalSince1970: 1_718_320_000)
        ),
        Quote(
            id: "quote-hk-kowloon-dental",
            clinicId: "hk-kowloon-care",
            userId: "seed-user-5",
            treatmentType: "牙科",
            estimatedCost: Decimal(1800),
            actualCost: nil,
            currency: "HKD",
            notes: "需先做術前檢查。",
            createdAt: Date(timeIntervalSince1970: 1_718_210_000)
        )
    ]

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
