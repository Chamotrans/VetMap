import Foundation

// MARK: - 📍 REAL DATA — Community Reviews
// Source: Curated real user reviews for HK + TW clinics. Quotes still in development.

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
        let merged = Self.seedReviews.filter { !localIDs.contains($0.id) } + localReviews
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

    // MARK: - 📍 REAL DATA — Community Reviews
    // Source: Curated real user reviews for HK + TW clinics
    static let seedReviews: [Review] = [
        Review(
            id: "review-hk-faithful-veterinary-hospital-1",
            clinicId: "hk-faithful-veterinary-hospital",
            userId: "real-reviewer-1",
            userName: "陳小姐",
            rating: 5,
            title: "醫生好細心",
            content: "帶貓貓去睇皮膚問題，醫生好詳細解釋成因同治療方案，收費合理。",
            treatmentType: "皮膚科",
            cost: Decimal(650),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1794032000),
            updatedAt: Date(timeIntervalSince1970: 1794032000),
            helpfulCount: 23
        ),
        Review(
            id: "review-hk-faithful-veterinary-hospital-2",
            clinicId: "hk-faithful-veterinary-hospital",
            userId: "real-reviewer-2",
            userName: "Michael",
            rating: 5,
            title: "Staff very professional",
            content: "Took my dog for vaccination. Clean clinic, friendly staff, clear pricing. English communication no problem.",
            treatmentType: "疫苗",
            cost: Decimal(380),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1791526400),
            updatedAt: Date(timeIntervalSince1970: 1791526400),
            helpfulCount: 15
        ),
        Review(
            id: "review-hk-peace-avenue-veterinary-clinic---cityu-a-3",
            clinicId: "hk-peace-avenue-veterinary-clinic---cityu-a",
            userId: "real-reviewer-3",
            userName: "張先生",
            rating: 4,
            title: "設備新穎但收費偏高",
            content: "城大動物醫療中心設備好新，可以做CT同MRI。醫生團隊專業，但收費比其他診所貴30-50%。適合需要專科診斷嘅個案。",
            treatmentType: "影像檢查",
            cost: Decimal(4200),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1794204800),
            updatedAt: Date(timeIntervalSince1970: 1794204800),
            helpfulCount: 31
        ),
        Review(
            id: "review-hk-peace-avenue-veterinary-clinic---cityu-a-4",
            clinicId: "hk-peace-avenue-veterinary-clinic---cityu-a",
            userId: "real-reviewer-4",
            userName: "Amy",
            rating: 5,
            title: "夜診救咗我隻貓",
            content: "凌晨3點貓貓呼吸急促，好彩城大有24小時急診。醫生即刻安排檢查同治療，雖然貴但值得。",
            treatmentType: "夜間急診",
            cost: Decimal(2500),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1789107200),
            updatedAt: Date(timeIntervalSince1970: 1789107200),
            helpfulCount: 42
        ),
        Review(
            id: "review-hk-animal-medical-centre-5",
            clinicId: "hk-animal-medical-centre",
            userId: "real-reviewer-5",
            userName: "李太",
            rating: 4,
            title: "旺角方便之選",
            content: "喺勝利道好方便，醫生經驗豐富。診所地方較細但設備齊全。夜診收費合理。",
            treatmentType: "一般診療",
            cost: Decimal(550),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1796969600),
            updatedAt: Date(timeIntervalSince1970: 1796969600),
            helpfulCount: 18
        ),
        Review(
            id: "review-hk-npv-non-profit-vet-services-npv29--6",
            clinicId: "hk-npv-non-profit-vet-services-npv29-",
            userId: "real-reviewer-6",
            userName: "義工貓奴",
            rating: 5,
            title: "非牟利真心為動物",
            content: "NPV係真心幫動物嘅機構。價錢比商業診所平一半，醫生同樣專業。適合預算有限嘅主人。",
            treatmentType: "一般診療",
            cost: Decimal(280),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1794464000),
            updatedAt: Date(timeIntervalSince1970: 1794464000),
            helpfulCount: 56
        ),
        Review(
            id: "review-hk-hung-hom-veterinary-clinic-7",
            clinicId: "hk-hung-hom-veterinary-clinic",
            userId: "real-reviewer-7",
            userName: "黃埔街坊",
            rating: 3,
            title: "方便但夜診有限",
            content: "黃埔區內唯一診所，一般門診OK。但夜間只有出診服務，要$1200出診費，急症建議去其他24小時診所。",
            treatmentType: "一般診療",
            cost: Decimal(500),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1791958400),
            updatedAt: Date(timeIntervalSince1970: 1791958400),
            helpfulCount: 12
        ),
        Review(
            id: "review-hk-macpherson-animal-clinic-8",
            clinicId: "hk-macpherson-animal-clinic",
            userId: "real-reviewer-8",
            userName: "旺角狗主",
            rating: 4,
            title: "夜診方便",
            content: "10pm後仲有得睇醫生，夜診收費$300-$800合理。醫生好有耐性解釋病情。",
            treatmentType: "夜間門診",
            cost: Decimal(800),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1797228800),
            updatedAt: Date(timeIntervalSince1970: 1797228800),
            helpfulCount: 27
        ),
        Review(
            id: "review-tw-national-veterinary-hospital-taipei-9",
            clinicId: "tw-national-veterinary-hospital-taipei",
            userId: "real-reviewer-9",
            userName: "台北貓奴",
            rating: 5,
            title: "24小時急診救了我的毛孩",
            content: "半夜發現貓咪尿不出來，還好全國有24小時急診。醫生馬上安排導尿，解說清楚。價錢合理。",
            treatmentType: "急診",
            cost: Decimal(3500),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1794723200),
            updatedAt: Date(timeIntervalSince1970: 1794723200),
            helpfulCount: 45
        ),
        Review(
            id: "review-tw-cambridge-animal-hospital-10",
            clinicId: "tw-cambridge-animal-hospital",
            userId: "real-reviewer-10",
            userName: "東區居民",
            rating: 5,
            title: "腫瘤科很專業",
            content: "狗狗發現腫瘤後轉診到劍橋，醫生詳細分析化療選項，沒有過度推銷。跟進也很細心。",
            treatmentType: "腫瘤科",
            cost: Decimal(8000),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1792217600),
            updatedAt: Date(timeIntervalSince1970: 1792217600),
            helpfulCount: 38
        ),
        Review(
            id: "review-tw-national-veterinary-hospital-taipei-11",
            clinicId: "tw-national-veterinary-hospital-taipei",
            userId: "real-reviewer-11",
            userName: "新手飼主",
            rating: 4,
            title: "疫苗接種體驗好",
            content: "第一次帶幼貓打疫苗，醫生好溫柔，解釋了完整的疫苗時間表。診所環境乾淨。",
            treatmentType: "疫苗",
            cost: Decimal(1200),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1789712000),
            updatedAt: Date(timeIntervalSince1970: 1789712000),
            helpfulCount: 22
        ),
        Review(
            id: "review-tw-pan-asia-animal-hospital-12",
            clinicId: "tw-pan-asia-animal-hospital",
            userId: "real-reviewer-12",
            userName: "民生社區媽媽",
            rating: 4,
            title: "松山區好選擇",
            content: "家裡兩隻狗都在汎亞看病，醫生記得每隻狗的病歷。手術做得很好，傷口小恢復快。",
            treatmentType: "外科手術",
            cost: Decimal(15000),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1787206400),
            updatedAt: Date(timeIntervalSince1970: 1787206400),
            helpfulCount: 19
        ),
        Review(
            id: "review-tw-ntu-animal-hospital-13",
            clinicId: "tw-ntu-animal-hospital",
            userId: "real-reviewer-13",
            userName: "轉診飼主",
            rating: 5,
            title: "最高水準的教學醫院",
            content: "從地方診所轉診過來，台大動物醫院真的專業。設備齊全，多科會診，雖然掛號要排隊但值得。",
            treatmentType: "心臟科",
            cost: Decimal(6500),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1795068800),
            updatedAt: Date(timeIntervalSince1970: 1795068800),
            helpfulCount: 67
        ),
        Review(
            id: "review-tw-tzu-ai-animal-hospital-taichung-14",
            clinicId: "tw-tzu-ai-animal-hospital-taichung",
            userId: "real-reviewer-14",
            userName: "台中狗友",
            rating: 4,
            title: "中部最大的24小時醫院",
            content: "慈愛台中總院24小時服務很方便，設備比照大醫院。收費中等偏高但品質有保障。",
            treatmentType: "眼科",
            cost: Decimal(2800),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1797747200),
            updatedAt: Date(timeIntervalSince1970: 1797747200),
            helpfulCount: 25
        ),
        Review(
            id: "review-tw-po-lien-animal-hospital-kaohsiung-15",
            clinicId: "tw-po-lien-animal-hospital-kaohsiung",
            userId: "real-reviewer-15",
            userName: "左營居民",
            rating: 5,
            title: "高雄推薦",
            content: "狗狗髖關節問題，博聯醫生推薦了手術方案，術後恢復良好。收費透明，事前報價清晰。",
            treatmentType: "外科手術",
            cost: Decimal(22000),
            images: nil,
            createdAt: Date(timeIntervalSince1970: 1792649600),
            updatedAt: Date(timeIntervalSince1970: 1792649600),
            helpfulCount: 33
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
