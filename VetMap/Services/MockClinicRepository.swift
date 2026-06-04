import Foundation

struct MockClinicRepository {
    private let localFileURL: URL
    private let fileManager: FileManager

    init(
        localFileURL: URL = Self.defaultLocalFileURL(),
        fileManager: FileManager = .default
    ) {
        self.localFileURL = localFileURL
        self.fileManager = fileManager
    }

    func fetchClinics() -> [VetClinic] {
        Self.clinics + fetchLocalClinics()
    }

    func addClinic(_ clinic: VetClinic) throws {
        var localClinics = fetchLocalClinics()

        if let existingIndex = localClinics.firstIndex(where: { $0.id == clinic.id }) {
            localClinics[existingIndex] = clinic
        } else {
            localClinics.append(clinic)
        }

        try saveLocalClinics(localClinics)
        NotificationCenter.default.post(
            name: .vetClinicRepositoryDidChange,
            object: nil,
            userInfo: [Self.changedClinicIDUserInfoKey: clinic.id]
        )
    }

    func fetchLocalClinics() -> [VetClinic] {
        guard fileManager.fileExists(atPath: localFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: localFileURL)
            return try Self.decoder.decode([VetClinic].self, from: data)
        } catch {
            return []
        }
    }

    private func saveLocalClinics(_ clinics: [VetClinic]) throws {
        let directory = localFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try Self.encoder.encode(clinics)
        try data.write(to: localFileURL, options: [.atomic])
    }

    private static func defaultLocalFileURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "VetMap", directoryHint: .isDirectory)
            .appending(path: "clinics.json")
    }

    static let changedClinicIDUserInfoKey = "changedClinicID"

    static let clinics: [VetClinic] = [
        VetClinic(
            id: "taipei-anxin",
            name: "安心動物醫院",
            address: "台北市大安區仁愛路一段1號",
            coordinate: ClinicCoordinate(latitude: 25.0381, longitude: 121.5432),
            phone: "+886-2-2345-6789",
            website: URL(string: "https://example.com/anxin"),
            openingHours: ["今日": "09:00-20:00", "急診": "電話確認"],
            services: ["一般診療", "牙科", "疫苗"],
            avgRating: 4.8,
            reviewCount: 186,
            priceLevel: 2,
            images: [],
            tags: ["貓友善", "收費清楚", "術前說明"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_000_000),
            reportedBy: "seed",
            verified: true
        ),
        VetClinic(
            id: "taipei-greenpaw",
            name: "綠爪獸醫診所",
            address: "台北市信義區松仁路88號",
            coordinate: ClinicCoordinate(latitude: 25.0368, longitude: 121.5684),
            phone: "+886-2-2766-2211",
            website: URL(string: "https://example.com/greenpaw"),
            openingHours: ["今日": "10:00-19:30"],
            services: ["皮膚科", "腫瘤諮詢", "影像檢查"],
            avgRating: 4.6,
            reviewCount: 94,
            priceLevel: 3,
            images: [],
            tags: ["專科轉診", "設備完整"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_000_000),
            reportedBy: "seed",
            verified: true
        ),
        VetClinic(
            id: "hk-harbour",
            name: "港灣動物醫療中心",
            address: "香港銅鑼灣禮頓道77號",
            coordinate: ClinicCoordinate(latitude: 22.2783, longitude: 114.1841),
            phone: "+852-2345-7788",
            website: URL(string: "https://example.com/harbourvet"),
            openingHours: ["今日": "09:30-21:00"],
            services: ["一般診療", "外科", "住院"],
            avgRating: 4.7,
            reviewCount: 142,
            priceLevel: 3,
            images: [],
            tags: ["英文溝通", "夜間門診", "透明報價"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_000_000),
            reportedBy: "seed",
            verified: true
        ),
        VetClinic(
            id: "hk-kowloon-care",
            name: "九龍毛孩診所",
            address: "香港旺角彌敦道610號",
            coordinate: ClinicCoordinate(latitude: 22.3186, longitude: 114.1693),
            phone: "+852-2999-1010",
            website: nil,
            openingHours: ["今日": "11:00-20:00"],
            services: ["疫苗", "牙科", "行為諮詢"],
            avgRating: 4.5,
            reviewCount: 67,
            priceLevel: 2,
            images: [],
            tags: ["初診友善", "價格中等"],
            createdAt: Date(timeIntervalSince1970: 1_718_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_718_000_000),
            reportedBy: "seed",
            verified: false
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
    static let vetClinicRepositoryDidChange = Notification.Name("vetClinicRepositoryDidChange")
}
