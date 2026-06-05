import XCTest
@testable import VetMap

final class VetMapModelTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_718_000_000)

    func testCoreModelsRoundTripThroughCodable() throws {
        try assertRoundTrip(makeClinic())
        try assertRoundTrip(makeReview())
        try assertRoundTrip(makeUserProfile())
        try assertRoundTrip(makeProduct())
        try assertRoundTrip(makeQuote())
        try assertRoundTrip(makeInsurance())
    }

    func testClinicRepositoryPersistsLocalClinics() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "clinics.json")

        let repository = MockClinicRepository(localFileURL: fileURL)
        let clinic = makeClinic(id: "local-clinic-1", name: "本機新增診所")

        try repository.addClinic(clinic)

        let reloadedRepository = MockClinicRepository(localFileURL: fileURL)
        let reloadedClinics = reloadedRepository.fetchClinics()

        XCTAssertTrue(reloadedClinics.contains(clinic))
        XCTAssertEqual(reloadedRepository.fetchLocalClinics(), [clinic])
    }

    func testClinicRepositoryPostsChangeNotificationAfterAddingClinic() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "clinics.json")

        let repository = MockClinicRepository(localFileURL: fileURL)
        let clinic = makeClinic(id: "local-clinic-2", name: "通知測試診所")
        var receivedNotification: Notification?
        let expectation = expectation(
            forNotification: .vetClinicRepositoryDidChange,
            object: nil
        ) { notification in
            receivedNotification = notification
            return true
        }

        try repository.addClinic(clinic)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(
            receivedNotification?.userInfo?[MockClinicRepository.changedClinicIDUserInfoKey] as? String,
            clinic.id
        )
    }

    @MainActor
    func testAddClinicViewModelKeepsBlankWebsiteNil() {
        let viewModel = AddClinicViewModel()
        viewModel.name = "空網站診所"
        viewModel.address = "台北市測試路1號"
        viewModel.phone = "+886-2-0000-0000"
        viewModel.website = "   "

        let clinic = viewModel.makeClinic()

        XCTAssertNil(clinic?.website)
    }

    @MainActor
    func testAddClinicViewModelUsesSelectedRegionCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .hongKong

        let clinic = viewModel.makeClinic()

        XCTAssertEqual(clinic?.coordinate.latitude, 22.3186)
        XCTAssertEqual(clinic?.coordinate.longitude, 114.1693)
    }

    @MainActor
    func testAddClinicViewModelUsesCustomCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .custom
        viewModel.latitude = "24.1477"
        viewModel.longitude = "120.6736"

        let clinic = viewModel.makeClinic()

        XCTAssertEqual(clinic?.coordinate.latitude, 24.1477)
        XCTAssertEqual(clinic?.coordinate.longitude, 120.6736)
    }

    @MainActor
    func testAddClinicViewModelRejectsInvalidCustomCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .custom
        viewModel.latitude = "200"
        viewModel.longitude = "120.6736"

        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertNil(viewModel.makeClinic())
    }

    @MainActor
    func testAddClinicViewModelLookupAddressPopulatesCustomCoordinate() async throws {
        let viewModel = makeValidAddClinicViewModel(
            geocodingService: StubGeocodingService(
                result: .success(
                    GeocodingResult(
                        coordinate: ClinicCoordinate(latitude: 22.2811234, longitude: 114.1589876),
                        displayName: "中環動物醫院"
                    )
                )
            )
        )
        viewModel.selectedRegion = .taipei

        await viewModel.lookupAddressLocation()

        XCTAssertEqual(viewModel.selectedRegion, .custom)
        XCTAssertEqual(viewModel.latitude, "22.281123")
        XCTAssertEqual(viewModel.longitude, "114.158988")
        XCTAssertEqual(viewModel.locationLookupState, .resolved("已找到：中環動物醫院"))

        let clinic = try XCTUnwrap(viewModel.makeClinic())
        XCTAssertEqual(clinic.coordinate.latitude, 22.281123, accuracy: 0.000001)
        XCTAssertEqual(clinic.coordinate.longitude, 114.158988, accuracy: 0.000001)
    }

    @MainActor
    func testAddClinicViewModelLookupAddressFailureKeepsRegionFallback() async {
        let viewModel = makeValidAddClinicViewModel(
            geocodingService: StubGeocodingService(result: .failure(StubGeocodingError.notFound))
        )
        viewModel.selectedRegion = .hongKong

        await viewModel.lookupAddressLocation()

        XCTAssertEqual(viewModel.selectedRegion, .hongKong)
        XCTAssertEqual(viewModel.locationLookupState, .failed("找不到位置，請手動輸入經緯度。"))
        XCTAssertTrue(viewModel.canSubmit)
    }

    @MainActor
    func testAddClinicViewModelEditingAddressClearsLookupState() async {
        let viewModel = makeValidAddClinicViewModel(
            geocodingService: StubGeocodingService(
                result: .success(
                    GeocodingResult(
                        coordinate: ClinicCoordinate(latitude: 22.2811234, longitude: 114.1589876),
                        displayName: "中環動物醫院"
                    )
                )
            )
        )

        await viewModel.lookupAddressLocation()
        viewModel.address = "香港灣仔皇后大道東"

        XCTAssertEqual(viewModel.locationLookupState, .idle)
    }

    private func assertRoundTrip<T: Codable & Equatable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(value)
        let decoded = try decoder.decode(T.self, from: data)

        XCTAssertEqual(decoded, value)
    }

    private func makeClinic(
        id: String = "clinic-1",
        name: String = "安心動物醫院"
    ) -> VetClinic {
        VetClinic(
            id: id,
            name: name,
            address: "台北市大安區仁愛路一段1號",
            coordinate: ClinicCoordinate(latitude: 25.0330, longitude: 121.5654),
            phone: "+886-2-1234-5678",
            website: URL(string: "https://example.com/clinic"),
            openingHours: ["Mon": "09:00-18:00"],
            services: ["一般診療", "牙科"],
            avgRating: 4.7,
            reviewCount: 128,
            priceLevel: 2,
            images: [URL(string: "https://example.com/clinic.jpg")!],
            tags: ["貓友善", "急診"],
            createdAt: date,
            updatedAt: date,
            reportedBy: "user-1",
            verified: true
        )
    }

    @MainActor
    private func makeValidAddClinicViewModel(
        geocodingService: GeocodingServicing = GeocodingService()
    ) -> AddClinicViewModel {
        let viewModel = AddClinicViewModel(geocodingService: geocodingService)
        viewModel.name = "座標測試診所"
        viewModel.address = "測試地址"
        viewModel.phone = "+886-2-0000-0000"
        return viewModel
    }

    private func makeReview() -> Review {
        Review(
            id: "review-1",
            clinicId: "clinic-1",
            userId: "user-1",
            userName: "Sunny",
            rating: 5,
            title: "細心可靠",
            content: "醫生解釋清楚，收費透明。",
            treatmentType: "疫苗接種",
            cost: 800,
            images: [URL(string: "https://example.com/review.jpg")!],
            createdAt: date,
            updatedAt: date,
            helpfulCount: 12
        )
    }

    private func makeUserProfile() -> UserProfile {
        UserProfile(
            id: "user-1",
            displayName: "Sunny",
            email: "sunny@example.com",
            photoURL: URL(string: "https://example.com/avatar.jpg"),
            isPremium: true,
            premiumExpiry: date,
            favoriteClinics: ["clinic-1"],
            savedProducts: ["product-1"],
            createdAt: date
        )
    }

    private func makeProduct() -> PetProduct {
        PetProduct(
            id: "product-1",
            name: "腸胃保健粉",
            description: "日常腸胃保健補充品。",
            category: "保健",
            price: 320,
            currency: "TWD",
            clinicId: "clinic-1",
            affiliateURL: URL(string: "https://example.com/product"),
            imageURL: URL(string: "https://example.com/product.jpg"),
            tags: ["犬貓適用"],
            createdAt: date
        )
    }

    private func makeQuote() -> Quote {
        Quote(
            id: "quote-1",
            clinicId: "clinic-1",
            userId: "user-1",
            treatmentType: "洗牙",
            estimatedCost: 3_000,
            actualCost: 3_200,
            currency: "TWD",
            notes: "含術前血檢。",
            createdAt: date
        )
    }

    private func makeInsurance() -> Insurance {
        Insurance(
            id: "insurance-1",
            providerName: "PetCare",
            planName: "基本醫療",
            description: "門診及手術保障。",
            monthlyPremium: 280,
            annualPremium: 3_000,
            coverage: ["手術", "住院"],
            exclusions: ["既有疾病"],
            website: URL(string: "https://example.com/insurance")!,
            contactPhone: "+886-2-2222-3333"
        )
    }
}

private struct StubGeocodingService: GeocodingServicing {
    let result: Result<GeocodingResult, Error>

    func resolve(address: String) async throws -> GeocodingResult {
        try result.get()
    }
}

private enum StubGeocodingError: Error {
    case notFound
}
