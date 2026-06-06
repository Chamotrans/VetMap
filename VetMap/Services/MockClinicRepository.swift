import Foundation

// MARK: - 📍 REAL DATA — Hong Kong Veterinary Clinics
// Source: ePetPet HK API (https://epetpet.com.hk/clinics) + manual verification.
// 29 clinics covering all 18 Hong Kong districts. Last updated: 2026-06-06.

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
        Self.hkClinics + fetchLocalClinics()
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

    // MARK: - 📍 REAL DATA — Hong Kong Veterinary Clinics
    // Source: ePetPet HK API (https://epetpet.com.hk/clinics) + manual verification
    // Data licensed for community use. Last updated: 2026-06-06
    static let hkClinics: [VetClinic] = [
        VetClinic(
            id: "hk-peace-avenue-veterinary-clinic---cityu-a",
            name: "太平道寵物診所 (PAVC) / 城大動物醫療中心",
            address: "九龍深水埗荔枝角道339號丰匯地下",
            coordinate: ClinicCoordinate(latitude: 22.3335, longitude: 114.158),
            phone: "36503000",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["一般診療", "24小時急診"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["夜診: 7pm-9am $1000"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-animal-medical-centre",
            name: "動物醫療中心",
            address: "旺角勝利道16號D地下",
            coordinate: ClinicCoordinate(latitude: 22.3193, longitude: 114.1708),
            phone: "27134155",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["一般診療", "夜間門診"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["夜診: 8pm-10pm $240 / 10pm-12am $400 / 12am後 $600"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-hung-hom-veterinary-clinic",
            name: "紅磡獸醫診所",
            address: "紅磡黃埔新村民泰街30號地下",
            coordinate: ClinicCoordinate(latitude: 22.305, longitude: 114.1898),
            phone: "23307566",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["一般診療", "緊急出診"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["夜診: 緊急出診 $1200（建議往其他24小時診所）"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-npv-non-profit-vet-services-npv29",
            name: "NPV非牟利獸醫服務協會（NPV29）",
            address: "太子基隆街29號",
            coordinate: ClinicCoordinate(latitude: 22.3245, longitude: 114.1657),
            phone: "23932070",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["一般診療", "緊急醫療", "非牟利"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["夜診: 12am後 $400", "非牟利"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-macpherson-animal-clinic",
            name: "麥花臣動物診所",
            address: "旺角洗衣街26號地下",
            coordinate: ClinicCoordinate(latitude: 22.319, longitude: 114.17),
            phone: "27812386",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["一般診療", "夜間門診"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["夜診: 10pm-12am $300 / 12am-10am $800"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "土瓜灣動物醫院",
            address: "香港九龍土瓜灣北帝街139號地舖",
            coordinate: ClinicCoordinate(latitude: 22.3236128, longitude: 114.1894662),
            phone: "27119909",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 5.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐5"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dc64ed544efd16046c",
            name: "Once And For All Veterinary Centre",
            address: "香港鴨脷洲利榮街2號新海怡廣場10樓1006-1007",
            coordinate: ClinicCoordinate(latitude: 22.2391667, longitude: 114.1527778),
            phone: "28828123/62158608",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 5.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐5"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "Pets Central 旺角動物醫院",
            address: "香港九龍旺角上海街484至488號順明大廈1樓和2樓",
            coordinate: ClinicCoordinate(latitude: 22.3164651, longitude: 114.168867),
            phone: "23092139",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 5.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐5"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dceac485c5cd6a0637",
            name: "萊奧動物醫療中心 LEAO Animal Medical Center",
            address: "Spring Sea Mansion, Shanghai St, Yau Ma Tei, Hong Kong",
            coordinate: ClinicCoordinate(latitude: 22.3135103, longitude: 114.1691526),
            phone: "25925376",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 5.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐5"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "博施寵物綜合醫療中心",
            address: "香港九龍荔枝角福華街571號曉悅6至8號地舖",
            coordinate: ClinicCoordinate(latitude: 22.3389556, longitude: 114.1525377),
            phone: "23686888",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 4.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐4"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "寵誠動物醫院",
            address: "香港九龍牛頭角馬蹄徑1號寶恩大廈7號地舖",
            coordinate: ClinicCoordinate(latitude: 22.3146811, longitude: 114.2220301),
            phone: "36112877",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 4.0,
            reviewCount: 1,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet ⭐4"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "動物醫療中心24小時中心",
            address: "香港九龍何文田自由道11號 VAU Residence 地下1號舖",
            coordinate: ClinicCoordinate(latitude: 22.318969, longitude: 114.174559),
            phone: "27134155",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["24-hour", "General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "鴨脷洲獸醫診所",
            address: "香港鴨脷洲利枝道138號1號舖",
            coordinate: ClinicCoordinate(latitude: 22.2436051, longitude: 114.1532428),
            phone: "25487100",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "恩典動物醫院",
            address: "香港九龍旺角勝利道28-32&36號新勝大樓C舖地下",
            coordinate: ClinicCoordinate(latitude: 22.319949, longitude: 114.1744528),
            phone: "27118482",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "雅發動物診所",
            address: "香港九龍深水埗欽州街65-71號榮業商業大廈4樓4室",
            coordinate: ClinicCoordinate(latitude: 22.3329358, longitude: 114.1617865),
            phone: "27088973",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dceac485c5cd6a0637",
            name: "Hong Kong Veterinary Specialty Services",
            address: "Flat A6, 5/F, Block A, Mai Hing Industrial Building, 16-18 Hing Yip St, Kwun Tong, Hong Kong",
            coordinate: ClinicCoordinate(latitude: 22.3088856, longitude: 114.225174),
            phone: "59953070",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["Diagnostics", "General practice", "Specialty services", "Surgery"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dcead9f1da3469d949",
            name: "24 hours Animal Emergency Centre 24小時動物急診中心",
            address: "G/F, 256 Shau Kei Wan Rd, Shau Kei Wan, Hong Kong",
            coordinate: ClinicCoordinate(latitude: 22.280141, longitude: 114.2251136),
            phone: "29157979",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["24-hour", "Emergency", "General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "雅各動物醫院",
            address: "香港西營盤第二街68-80號地下",
            coordinate: ClinicCoordinate(latitude: 22.286033, longitude: 114.14156),
            phone: "25400228",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad9893b2c2f0a8731",
            name: "動物王國醫院",
            address: "香港銅鑼灣威菲路道25至27號佳景大廈2-3號舖",
            coordinate: ClinicCoordinate(latitude: 22.2860011, longitude: 114.1906908),
            phone: "25780321",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "動物獸醫中心-安健獸醫中心",
            address: "香港新界大埔仁興街54號地下",
            coordinate: ClinicCoordinate(latitude: 22.449307, longitude: 114.1641616),
            phone: "26561168",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "哈比動物牙科及口腔手術中心",
            address: "香港新界沙田大圍積信街69-75地下號A地舖",
            coordinate: ClinicCoordinate(latitude: 22.3767729, longitude: 114.1788858),
            phone: "28506088",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["Dentistry", "General practice", "Surgery"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "優活動物診所",
            address: "香港新界元朗鳳攸東街9號好順意大廈地下36及37號舖",
            coordinate: ClinicCoordinate(latitude: 22.4445376, longitude: 114.0222076),
            phone: "29659518",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "柏德獸醫診所",
            address: "香港新界屯門青山公路385號嘉喜利大廈12號舖",
            coordinate: ClinicCoordinate(latitude: 22.3884598, longitude: 113.9800707),
            phone: "24042511",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "貝澳獸醫診所",
            address: "香港大嶼山貝澳新圍村地下",
            coordinate: ClinicCoordinate(latitude: 22.245461, longitude: 113.977841),
            phone: "34866100",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "角落獸醫診所",
            address: "香港九龍黃大仙環鳳街68號鑽嶺低層地下01號",
            coordinate: ClinicCoordinate(latitude: 22.3449174, longitude: 114.1986224),
            phone: "26626232",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "將軍澳獸醫中心",
            address: "香港新界將軍澳唐俊街21號地下翩匯坊G18號舖",
            coordinate: ClinicCoordinate(latitude: 22.3030015, longitude: 114.2634544),
            phone: "29157007",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "Dr. George's 獸醫醫療中心",
            address: "香港新界荃灣享和街36號好景樓地舖",
            coordinate: ClinicCoordinate(latitude: 22.371839, longitude: 114.1112672),
            phone: "24988102",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "粉嶺動物醫院",
            address: "香港新界粉嶺聯和墟聯安街31號4號地舖",
            coordinate: ClinicCoordinate(latitude: 22.4998322, longitude: 114.1432444),
            phone: "26776046",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
        ),
        VetClinic(
            id: "hk-69dad98a3b2c2f0a8731",
            name: "豐盈動物腫瘤中心",
            address: "香港新界葵涌葵豐街38至42號大鴻輝(葵涌)中心2期地下1號舖",
            coordinate: ClinicCoordinate(latitude: 22.3555118, longitude: 114.1253095),
            phone: "34263500",
            website: nil,
            openingHours: ["今日": "請致電查詢"],
            services: ["General practice", "Internal medicine", "Specialty services", "Surgery"],
            avgRating: 0.0,
            reviewCount: 0,
            priceLevel: 2,
            images: [],
            tags: ["ePetPet"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "epetpet-hk",
            verified: true
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
