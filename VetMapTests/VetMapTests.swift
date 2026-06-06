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

    func testCommunityRepositoryPersistsLocalReviewsAndPostsChangeNotification() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")

        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let review = makeReview(
            id: "local-review-1",
            clinicId: "taipei-anxin",
            title: "本機評價測試"
        )
        var receivedNotification: Notification?
        let expectation = expectation(
            forNotification: .vetCommunityRepositoryDidChange,
            object: nil
        ) { notification in
            receivedNotification = notification
            return true
        }

        try repository.addReview(review)

        wait(for: [expectation], timeout: 1)

        let reloadedRepository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let reloadedReviews = reloadedRepository.fetchReviews(for: "taipei-anxin")

        XCTAssertTrue(reloadedReviews.contains(review))
        XCTAssertEqual(reloadedRepository.fetchLocalReviews(), [review])
        XCTAssertEqual(
            receivedNotification?.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String,
            review.clinicId
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

    func testClinicSearchFilterMatchesNameAddressServicesAndTags() {
        var filter = ClinicSearchFilter()
        filter.query = "牙科"

        let results = filter.results(from: MockClinicRepository.hkClinics)

        XCTAssertEqual(results.map(\.id), ["taipei-anxin", "hk-kowloon-care"])
    }

    func testClinicSearchFilterCombinesRegionVerificationAndPrice() {
        var filter = ClinicSearchFilter()
        filter.region = .hongKong
        filter.verifiedOnly = true
        filter.price = .premium

        let results = filter.results(from: MockClinicRepository.hkClinics)

        XCTAssertEqual(results.map(\.id), ["hk-harbour"])
    }

    @MainActor
    func testMapViewModelClearsSelectionWhenFiltersHaveNoResults() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "clinics.json")
        let repository = MockClinicRepository(localFileURL: fileURL)
        let viewModel = MapViewModel(repository: repository)

        viewModel.filter.query = "完全不存在的診所"

        XCTAssertTrue(viewModel.filteredClinics.isEmpty)
        XCTAssertNil(viewModel.selectedClinicID)
    }

    @MainActor
    func testClinicDetailViewModelLoadsSeedCommunityData() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)

        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        XCTAssertFalse(viewModel.reviews.isEmpty)
        XCTAssertFalse(viewModel.quotes.isEmpty)
        XCTAssertEqual(viewModel.reviews.map(\.clinicId).uniqueValues, [clinic.id])
        XCTAssertEqual(viewModel.quotes.map(\.clinicId).uniqueValues, [clinic.id])
    }

    @MainActor
    func testClinicDetailViewModelAddsReview() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        let didAddReview = viewModel.addReview(
            ReviewDraft(
                rating: 5,
                title: "  新增成功  ",
                content: "  醫生解釋清楚，費用亦透明。  ",
                treatmentType: "洗牙",
                cost: Decimal(3_000)
            )
        )

        XCTAssertTrue(didAddReview)
        XCTAssertNil(viewModel.storageError)
        XCTAssertTrue(viewModel.reviews.contains { $0.title == "新增成功" })
        XCTAssertTrue(repository.fetchLocalReviews().contains { $0.title == "新增成功" })
    }

    @MainActor
    func testClinicDetailViewModelRejectsInvalidReviewDraft() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)
        let initialReviewCount = viewModel.reviews.count

        let didAddReview = viewModel.addReview(
            ReviewDraft(
                rating: 0,
                title: " ",
                content: "內容",
                treatmentType: "",
                cost: nil
            )
        )

        XCTAssertFalse(didAddReview)
        XCTAssertEqual(viewModel.reviews.count, initialReviewCount)
        XCTAssertEqual(viewModel.storageError, "請填寫評分、標題和內容。")
        XCTAssertTrue(repository.fetchLocalReviews().isEmpty)
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

    // MARK: - ReviewViewModel Tests

    @MainActor
    func testReviewViewModelLoadsReviewsForClinic() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)

        XCTAssertGreaterThan(viewModel.reviews.count, 0)
        XCTAssertTrue(viewModel.reviews.allSatisfy { $0.clinicId == "taipei-anxin" })
    }

    @MainActor
    func testReviewViewModelSortsByNewest() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)

        viewModel.sortOrder = .newest
        let sorted = viewModel.sortedReviews

        guard sorted.count >= 2 else {
            XCTFail("Expected at least 2 reviews for sorting test")
            return
        }
        for i in 0..<(sorted.count - 1) {
            XCTAssertGreaterThanOrEqual(sorted[i].createdAt, sorted[i + 1].createdAt)
        }
    }

    @MainActor
    func testReviewViewModelSortsByHighestRating() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let clinicId = "test-rating-sort"

        var low = makeReview(id: "low", clinicId: clinicId, title: "Low")
        low.rating = 2
        try! repository.addReview(low)

        var high = makeReview(id: "high", clinicId: clinicId, title: "High")
        high.rating = 5
        try! repository.addReview(high)

        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)
        viewModel.sortOrder = .highestRating
        let sorted = viewModel.sortedReviews

        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted[0].rating, 5)
        XCTAssertEqual(sorted[1].rating, 2)
    }

    @MainActor
    func testReviewViewModelSortsByMostHelpful() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let clinicId = "test-helpful-sort"

        var less = makeReview(id: "less", clinicId: clinicId, title: "Less")
        less.helpfulCount = 3
        try! repository.addReview(less)

        var more = makeReview(id: "more", clinicId: clinicId, title: "More")
        more.helpfulCount = 10
        try! repository.addReview(more)

        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)
        viewModel.sortOrder = .mostHelpful
        let sorted = viewModel.sortedReviews

        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted[0].id, "more")
        XCTAssertEqual(sorted[1].id, "less")
    }

    @MainActor
    func testReviewViewModelMarksHelpful() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)

        guard let firstReview = viewModel.reviews.first else {
            XCTFail("No reviews loaded")
            return
        }
        let originalCount = firstReview.helpfulCount

        viewModel.markHelpful(firstReview.id)

        guard let updatedReview = viewModel.reviews.first(where: { $0.id == firstReview.id }) else {
            XCTFail("Review not found after marking helpful")
            return
        }
        XCTAssertEqual(updatedReview.helpfulCount, originalCount + 1)
    }

    // MARK: - QuoteViewModel Tests

    @MainActor
    func testQuoteViewModelLoadsQuotesForClinic() {
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(localQuotesFileURL: quotesURL)
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)

        XCTAssertGreaterThan(viewModel.quotes.count, 0)
        XCTAssertTrue(viewModel.quotes.allSatisfy { $0.clinicId == "taipei-anxin" })
    }

    @MainActor
    func testQuoteViewModelAddsQuote() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.quotes.count

        let success = viewModel.addQuote(
            treatmentType: "洗牙",
            estimatedCost: Decimal(3000),
            actualCost: nil,
            currency: "TWD",
            notes: "測試報價"
        )

        XCTAssertTrue(success)
        XCTAssertEqual(viewModel.quotes.count, initialCount + 1)
        XCTAssertTrue(viewModel.quotes.contains { $0.treatmentType == "洗牙" })
        XCTAssertNil(viewModel.storageError)
    }

    @MainActor
    func testQuoteViewModelEmptyQuotesForUnknownClinic() {
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(localQuotesFileURL: quotesURL)
        let viewModel = QuoteViewModel(clinicId: "bogus-clinic-999", repository: repository)

        XCTAssertTrue(viewModel.quotes.isEmpty)
    }

    // MARK: - ProductViewModel Tests

    @MainActor
    func testProductViewModelLoadsAllProducts() {
        let viewModel = ProductViewModel()

        XCTAssertFalse(viewModel.products.isEmpty)
        XCTAssertGreaterThan(viewModel.products.count, 0)
    }

    @MainActor
    func testProductViewModelFiltersByCategory() {
        let viewModel = ProductViewModel()
        viewModel.selectedCategory = "食品"

        let filtered = viewModel.filteredProducts
        XCTAssertFalse(filtered.isEmpty)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "食品" })
    }

    // MARK: - InsuranceViewModel Tests

    @MainActor
    func testInsuranceViewModelLoadsAllPlans() {
        let viewModel = InsuranceViewModel()

        XCTAssertFalse(viewModel.plans.isEmpty)
        XCTAssertGreaterThan(viewModel.plans.count, 0)
    }

    @MainActor
    func testInsuranceViewModelSortsByPremiumLowToHigh() {
        let viewModel = InsuranceViewModel()
        viewModel.sortOrder = .lowToHigh
        let sorted = viewModel.sortedPlans

        guard sorted.count >= 2 else {
            XCTFail("Expected at least 2 plans for sorting test")
            return
        }
        for i in 0..<(sorted.count - 1) {
            XCTAssertLessThanOrEqual(sorted[i].monthlyPremium, sorted[i + 1].monthlyPremium)
        }
    }

    @MainActor
    func testInsuranceViewModelSortsByPremiumHighToLow() {
        let viewModel = InsuranceViewModel()
        viewModel.sortOrder = .highToLow
        let sorted = viewModel.sortedPlans

        guard sorted.count >= 2 else {
            XCTFail("Expected at least 2 plans for sorting test")
            return
        }
        for i in 0..<(sorted.count - 1) {
            XCTAssertGreaterThanOrEqual(sorted[i].monthlyPremium, sorted[i + 1].monthlyPremium)
        }
    }

    // MARK: - MockCommunityRepository Quote Persistence

    func testCommunityRepositoryPersistsLocalQuotesAndPostsChangeNotification() throws {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")

        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let quote = makeQuote(
            id: "local-quote-1",
            clinicId: "taipei-anxin"
        )
        var receivedNotification: Notification?
        let expectation = expectation(
            forNotification: .vetCommunityRepositoryDidChange,
            object: nil
        ) { notification in
            receivedNotification = notification
            return true
        }

        try repository.addQuote(quote)

        wait(for: [expectation], timeout: 1)

        let reloadedRepository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let reloadedQuotes = reloadedRepository.fetchQuotes(for: "taipei-anxin")

        XCTAssertTrue(reloadedQuotes.contains(quote))
        XCTAssertTrue(reloadedRepository.fetchLocalQuotes().contains(quote))
        XCTAssertEqual(
            receivedNotification?.userInfo?[MockCommunityRepository.changedClinicIDUserInfoKey] as? String,
            quote.clinicId
        )
    }

    // MARK: - ClinicSearchFilter Additional Tests

    func testClinicSearchFilterEmptyQueryReturnsAll() {
        let filter = ClinicSearchFilter()
        let results = filter.results(from: MockClinicRepository.hkClinics)

        XCTAssertEqual(results.count, MockClinicRepository.hkClinics.count)
    }

    func testClinicSearchFilterPriceBudget() {
        var filter = ClinicSearchFilter()
        filter.price = .budget
        let results = filter.results(from: MockClinicRepository.hkClinics)

        XCTAssertTrue(results.allSatisfy { $0.priceLevel <= 1 })
    }

    func testClinicSearchFilterPriceModerate() {
        var filter = ClinicSearchFilter()
        filter.price = .moderate
        let results = filter.results(from: MockClinicRepository.hkClinics)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.priceLevel <= 2 })
        XCTAssertEqual(results.map(\.id).sorted(), ["hk-kowloon-care", "taipei-anxin"])
    }

    // MARK: - ReviewDraft Validation Tests

    @MainActor
    func testReviewDraftRequiresRatingInRange() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        XCTAssertTrue(viewModel.addReview(
            ReviewDraft(rating: 1, title: "標題", content: "內容", treatmentType: "", cost: nil)
        ))

        XCTAssertTrue(viewModel.addReview(
            ReviewDraft(rating: 5, title: "標題2", content: "內容2", treatmentType: "", cost: nil)
        ))

        let countBeforeInvalid = viewModel.reviews.count
        XCTAssertFalse(viewModel.addReview(
            ReviewDraft(rating: 6, title: "標題", content: "內容", treatmentType: "", cost: nil)
        ))
        XCTAssertEqual(viewModel.reviews.count, countBeforeInvalid)
        XCTAssertEqual(viewModel.storageError, "請填寫評分、標題和內容。")
    }

    @MainActor
    func testReviewDraftTrimsWhitespace() {
        let viewModel = AddClinicViewModel()
        viewModel.name = "  測試診所  "
        viewModel.address = "  測試地址  "
        viewModel.phone = "  +886-2-0000-0000  "
        viewModel.selectedRegion = .taipei

        let clinic = viewModel.makeClinic()

        XCTAssertEqual(clinic?.name, "測試診所")
        XCTAssertEqual(clinic?.address, "測試地址")
        XCTAssertEqual(clinic?.phone, "+886-2-0000-0000")
    }

    // MARK: - AuthViewModel Tests (Local-Only Mode)

    @MainActor
    func testAuthViewModelInitialStateInLocalMode() {
        let viewModel = AuthViewModel()

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testAuthViewModelSignUpReturnsErrorMessageInLocalMode() async {
        let viewModel = AuthViewModel()

        await viewModel.signUp(email: "test@example.com", password: "password123", displayName: "Test User")

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        XCTAssertEqual(viewModel.errorMessage, "Firebase SDK 尚未連結，無法註冊。")
    }

    @MainActor
    func testAuthViewModelSignInReturnsErrorMessageInLocalMode() async {
        let viewModel = AuthViewModel()

        await viewModel.signIn(email: "test@example.com", password: "password123")

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        XCTAssertEqual(viewModel.errorMessage, "Firebase SDK 尚未連結，無法登入。")
    }

    @MainActor
    func testAuthViewModelSignOutClearsStateInLocalMode() {
        let viewModel = AuthViewModel()

        viewModel.signOut()

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testAuthViewModelSignOutClearsExistingError() {
        let viewModel = AuthViewModel()
        viewModel.errorMessage = "Some prior error"

        viewModel.signOut()

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testAuthViewModelErrorIsSetBeforeEachAuthCall() async {
        let viewModel = AuthViewModel()
        viewModel.errorMessage = "Old error"

        await viewModel.signIn(email: "test@example.com", password: "password123")

        XCTAssertNotEqual(viewModel.errorMessage, "Old error")
        XCTAssertEqual(viewModel.errorMessage, "Firebase SDK 尚未連結，無法登入。")
    }

    // MARK: - PremiumViewModel Tests

    @MainActor
    func testPremiumViewModelInitialState() {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)

        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.purchaseSuccess)
        XCTAssertFalse(viewModel.isPremium)
        XCTAssertNil(viewModel.selectedPlan)
        XCTAssertNil(viewModel.purchaseError)
        XCTAssertTrue(viewModel.products.isEmpty)
    }

    @MainActor
    func testPremiumViewModelPurchaseFailsWithoutLoadedProducts() async {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)

        await viewModel.purchase(.monthly)

        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.purchaseSuccess)
        XCTAssertEqual(viewModel.purchaseError, "找不到對應產品，請稍後再試")
        // selectedPlan is only set when a matching product is found, which fails here
        XCTAssertNil(viewModel.selectedPlan)
    }

    @MainActor
    func testPremiumViewModelPurchaseYearlyFailsWithoutLoadedProducts() async {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)

        await viewModel.purchase(.yearly)

        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.purchaseSuccess)
        XCTAssertEqual(viewModel.purchaseError, "找不到對應產品，請稍後再試")
        // selectedPlan is only set when a matching product is found, which fails here
        XCTAssertNil(viewModel.selectedPlan)
    }

    @MainActor
    func testPremiumViewModelRestoreFindsNoPurchases() async {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)

        await viewModel.restore()

        XCTAssertFalse(viewModel.isPurchasing)
        XCTAssertFalse(viewModel.purchaseSuccess)
        XCTAssertEqual(viewModel.purchaseError, "找不到可恢復的購買項目")
    }

    @MainActor
    func testPremiumViewModelRestoreResetsFlagsOnCompletion() async {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)
        viewModel.purchaseError = "previous error"
        viewModel.purchaseSuccess = true

        await viewModel.restore()

        // isPurchasing should always be false after restore completes
        XCTAssertFalse(viewModel.isPurchasing)
    }

    @MainActor
    func testPremiumViewModelProductForPlanReturnsNilWithEmptyProducts() {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)

        XCTAssertNil(viewModel.product(for: .monthly))
        XCTAssertNil(viewModel.product(for: .yearly))
    }

    @MainActor
    func testPremiumViewModelPurchaseResetsErrorBeforeAttempt() async {
        let service = IAPService()
        let viewModel = PremiumViewModel(service: service)
        viewModel.purchaseError = "Previous error"

        await viewModel.purchase(.monthly)

        // Error should be updated to the new failure reason, not the old one
        XCTAssertNotEqual(viewModel.purchaseError, "Previous error")
        XCTAssertEqual(viewModel.purchaseError, "找不到對應產品，請稍後再試")
    }

    // MARK: - ReviewViewModel Additional Tests

    @MainActor
    func testReviewViewModelReloadsOnMatchingRepositoryNotification() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.reviews.count

        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [MockCommunityRepository.changedClinicIDUserInfoKey: "taipei-anxin"]
        )

        let expectation = XCTestExpectation(description: "Wait for notification processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(viewModel.reviews.count, initialCount)
    }

    @MainActor
    func testReviewViewModelIgnoresNotificationForOtherClinic() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialReviews = viewModel.reviews

        // Post notification for a different clinic
        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [MockCommunityRepository.changedClinicIDUserInfoKey: "hk-harbour"]
        )

        let expectation = XCTestExpectation(description: "Wait for notification processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Reviews should be unchanged since notification was for a different clinic
        XCTAssertEqual(viewModel.reviews.map(\.id), initialReviews.map(\.id))
    }

    @MainActor
    func testReviewViewModelMarkHelpfulOnNonExistentReviewIsNoop() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialReviews = viewModel.reviews

        viewModel.markHelpful("nonexistent-review-id")

        // Reviews should be completely unchanged
        XCTAssertEqual(viewModel.reviews.map(\.id), initialReviews.map(\.id))
        XCTAssertEqual(viewModel.reviews.map(\.helpfulCount), initialReviews.map(\.helpfulCount))
    }

    // MARK: - QuoteViewModel Additional Tests

    @MainActor
    func testQuoteViewModelDefaultOrderIsCreatedAtDescending() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)

        // Add a second quote with an older date so we have 2+ to sort
        let olderQuote = makeQuote(id: "quote-sort-test-older", clinicId: "taipei-anxin")
        try! repository.addQuote(olderQuote)
        viewModel.loadQuotes()

        let quotes = viewModel.quotes

        guard quotes.count >= 2 else {
            XCTFail("Expected at least 2 quotes for sort test")
            return
        }
        for i in 0..<(quotes.count - 1) {
            XCTAssertGreaterThanOrEqual(quotes[i].createdAt, quotes[i + 1].createdAt)
        }
    }

    @MainActor
    func testQuoteViewModelRejectsEmptyTreatmentType() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.quotes.count

        let success = viewModel.addQuote(
            treatmentType: "   ",
            estimatedCost: Decimal(1000),
            actualCost: nil,
            currency: "TWD",
            notes: "test"
        )

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelRejectsZeroEstimatedCost() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.quotes.count

        let success = viewModel.addQuote(
            treatmentType: "洗牙",
            estimatedCost: Decimal(0),
            actualCost: nil,
            currency: "TWD",
            notes: "test"
        )

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelRejectsNegativeEstimatedCost() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.quotes.count

        let success = viewModel.addQuote(
            treatmentType: "洗牙",
            estimatedCost: Decimal(-1),
            actualCost: nil,
            currency: "TWD",
            notes: "test"
        )

        XCTAssertFalse(success)
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelTrimsWhitespaceFromTreatmentType() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)

        let success = viewModel.addQuote(
            treatmentType: "  一般診療  ",
            estimatedCost: Decimal(500),
            actualCost: nil,
            currency: "TWD",
            notes: "test"
        )

        XCTAssertTrue(success)
        XCTAssertTrue(viewModel.quotes.contains { $0.treatmentType == "一般診療" })
        XCTAssertFalse(viewModel.quotes.contains { $0.treatmentType.hasPrefix(" ") })
    }

    @MainActor
    func testQuoteViewModelTrimsWhitespaceFromNotes() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)

        let success = viewModel.addQuote(
            treatmentType: "健檢",
            estimatedCost: Decimal(1500),
            actualCost: nil,
            currency: "TWD",
            notes: "  含血檢  "
        )

        XCTAssertTrue(success)
        XCTAssertTrue(viewModel.quotes.contains { $0.notes == "含血檢" })
    }

    @MainActor
    func testQuoteViewModelReloadsOnNotification() {
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        let viewModel = QuoteViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialCount = viewModel.quotes.count

        NotificationCenter.default.post(
            name: .vetCommunityRepositoryDidChange,
            object: nil,
            userInfo: [MockCommunityRepository.changedClinicIDUserInfoKey: "taipei-anxin"]
        )

        let expectation = XCTestExpectation(description: "Wait for notification processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(viewModel.quotes.count, initialCount)
    }

    // MARK: - ProductViewModel Additional Tests

    @MainActor
    func testProductViewModelAllCategoryReturnsUnfilteredProducts() {
        let viewModel = ProductViewModel()
        viewModel.selectedCategory = "保健"
        let filteredCount = viewModel.filteredProducts.count

        viewModel.selectedCategory = "全部"

        XCTAssertEqual(viewModel.filteredProducts.count, viewModel.products.count)
        XCTAssertGreaterThan(viewModel.filteredProducts.count, filteredCount)
    }

    @MainActor
    func testProductViewModelFilterByNonExistentCategoryReturnsEmpty() {
        let viewModel = ProductViewModel()
        viewModel.selectedCategory = "不存在的分類"

        XCTAssertTrue(viewModel.filteredProducts.isEmpty)
    }

    @MainActor
    func testProductViewModelCategoriesListContainsExpectedValues() {
        let categories = ProductViewModel.categories

        XCTAssertEqual(categories.count, 5)
        XCTAssertTrue(categories.contains("全部"))
        XCTAssertTrue(categories.contains("食品"))
        XCTAssertTrue(categories.contains("玩具"))
        XCTAssertTrue(categories.contains("保健"))
        XCTAssertTrue(categories.contains("藥品"))
    }

    @MainActor
    func testProductViewModelEachProductHasValidCategory() {
        let viewModel = ProductViewModel()

        for product in viewModel.products {
            XCTAssertTrue(
                ProductViewModel.categories.contains(product.category),
                "Product \(product.id) has unknown category: \(product.category)"
            )
        }
    }

    @MainActor
    func testProductViewModelFilteredByFoodCategory() {
        let viewModel = ProductViewModel()
        viewModel.selectedCategory = "食品"

        let filtered = viewModel.filteredProducts

        XCTAssertFalse(filtered.isEmpty)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "食品" })
    }

    @MainActor
    func testProductViewModelFilteredByMedicineCategory() {
        let viewModel = ProductViewModel()
        viewModel.selectedCategory = "藥品"

        let filtered = viewModel.filteredProducts

        XCTAssertFalse(filtered.isEmpty)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "藥品" })
    }

    // MARK: - InsuranceViewModel Additional Tests

    @MainActor
    func testInsuranceViewModelCurrencyForHKProviderReturnsHKD() {
        let viewModel = InsuranceViewModel()
        guard let hkPlan = viewModel.plans.first(where: {
            $0.website.absoluteString.contains(".hk")
        }) else {
            XCTFail("No HK plan found for currency test")
            return
        }

        XCTAssertEqual(viewModel.currency(for: hkPlan), "HKD")
    }

    @MainActor
    func testInsuranceViewModelCurrencyForTWProviderReturnsTWD() {
        let viewModel = InsuranceViewModel()
        guard let twPlan = viewModel.plans.first(where: {
            !$0.website.absoluteString.contains(".hk")
        }) else {
            XCTFail("No TW plan found for currency test")
            return
        }

        XCTAssertEqual(viewModel.currency(for: twPlan), "TWD")
    }

    @MainActor
    func testInsuranceViewModelPlansWithSimilarPremiumExcludesSelf() {
        let viewModel = InsuranceViewModel()
        guard let firstPlan = viewModel.plans.first else {
            XCTFail("No plans loaded")
            return
        }

        let similar = viewModel.plansWithSimilarPremium(to: firstPlan, count: 3)

        XCTAssertFalse(similar.contains(where: { $0.id == firstPlan.id }))
    }

    @MainActor
    func testInsuranceViewModelPlansWithSimilarPremiumRespectsCount() {
        let viewModel = InsuranceViewModel()
        guard let firstPlan = viewModel.plans.first else {
            XCTFail("No plans loaded")
            return
        }

        let similar = viewModel.plansWithSimilarPremium(to: firstPlan, count: 2)

        XCTAssertLessThanOrEqual(similar.count, 2)
    }

    @MainActor
    func testInsuranceViewModelSortedPlansAreInCorrectPremiumOrder() {
        let viewModel = InsuranceViewModel()

        viewModel.sortOrder = .lowToHigh
        let lowToHigh = viewModel.sortedPlans
        for i in 0..<(lowToHigh.count - 1) {
            XCTAssertLessThanOrEqual(lowToHigh[i].monthlyPremium, lowToHigh[i + 1].monthlyPremium)
        }

        viewModel.sortOrder = .highToLow
        let highToLow = viewModel.sortedPlans
        for i in 0..<(highToLow.count - 1) {
            XCTAssertGreaterThanOrEqual(highToLow[i].monthlyPremium, highToLow[i + 1].monthlyPremium)
        }
    }

    @MainActor
    func testInsuranceViewModelAllPlansHaveRequiredFields() {
        let viewModel = InsuranceViewModel()

        for plan in viewModel.plans {
            XCTAssertFalse(plan.id.isEmpty, "Plan missing id")
            XCTAssertFalse(plan.providerName.isEmpty, "Plan \(plan.id) missing providerName")
            XCTAssertFalse(plan.planName.isEmpty, "Plan \(plan.id) missing planName")
            XCTAssertGreaterThan(plan.monthlyPremium, 0, "Plan \(plan.id) has non-positive premium")
            XCTAssertFalse(plan.coverage.isEmpty, "Plan \(plan.id) has no coverage")
        }
    }

    // MARK: - ClinicCoordinate Tests

    func testClinicCoordinateEquatable() {
        let a = ClinicCoordinate(latitude: 25.0, longitude: 121.0)
        let b = ClinicCoordinate(latitude: 25.0, longitude: 121.0)
        let c = ClinicCoordinate(latitude: 25.1, longitude: 121.0)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
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

    private func makeReview(
        id: String = "review-1",
        clinicId: String = "clinic-1",
        title: String = "細心可靠"
    ) -> Review {
        Review(
            id: id,
            clinicId: clinicId,
            userId: "user-1",
            userName: "Sunny",
            rating: 5,
            title: title,
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

    private func makeQuote(
        id: String = "quote-1",
        clinicId: String = "clinic-1"
    ) -> Quote {
        Quote(
            id: id,
            clinicId: clinicId,
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

private extension Array where Element: Hashable {
    var uniqueValues: [Element] {
        Array(Set(self)).sorted { "\($0)" < "\($1)" }
    }
}
