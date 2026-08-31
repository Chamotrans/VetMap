import CoreLocation
import XCTest
@testable import VetMap

final class VetMapModelTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_718_000_000)

    private enum TestCommunityAction: Equatable {
        case addReview
        case report(String)
        case message(String)
    }

    func testAuthenticatedActionWaitsForRestoreAndResumesExactlyOnce() {
        var continuation = AuthenticatedActionContinuation<TestCommunityAction>()

        XCTAssertEqual(
            continuation.request(.addReview, authentication: .loading),
            .waitForAuthentication
        )
        XCTAssertTrue(continuation.hasPendingAction)
        XCTAssertNil(continuation.takeIfAuthenticated(.loading))
        XCTAssertEqual(
            continuation.takeIfAuthenticated(.signedIn(userID: "alice")),
            .addReview
        )
        XCTAssertNil(
            continuation.takeIfAuthenticated(.signedIn(userID: "alice")),
            "authState, user ID, and LoginView onDismiss callbacks must not replay intent"
        )
        XCTAssertFalse(continuation.hasPendingAction)
    }

    func testAuthenticatedActionCancelClearsSignedOutIntent() {
        var continuation = AuthenticatedActionContinuation<TestCommunityAction>()

        XCTAssertEqual(
            continuation.request(.report("spam"), authentication: .signedOut),
            .presentLogin
        )
        XCTAssertTrue(continuation.hasPendingAction)

        continuation.cancel()

        XCTAssertNil(
            continuation.takeIfAuthenticated(.signedIn(userID: "alice"))
        )
    }

    func testFreshAuthenticatedGestureSupersedesRestoredIntent() {
        var continuation = AuthenticatedActionContinuation<TestCommunityAction>()
        _ = continuation.request(.addReview, authentication: .loading)

        XCTAssertEqual(
            continuation.request(
                .message("bob"),
                authentication: .signedIn(userID: "alice")
            ),
            .perform(.message("bob"))
        )
        XCTAssertFalse(
            continuation.hasPendingAction,
            "a later auth callback must not replay the older loading-state action"
        )
    }

    func testQuoteDraftSnapshotPreservesExactSubmissionValues() {
        let draft = QuoteDraft(
            treatmentType: "夜診",
            estimatedCost: Decimal(string: "880.50")!,
            actualCost: Decimal(string: "900.00"),
            currency: "HKD",
            notes: "登入前輸入的草稿"
        )
        var continuation = AuthenticatedActionContinuation<QuoteDraft>()

        continuation.deferUntilAuthenticated(draft)

        XCTAssertEqual(
            continuation.takeIfAuthenticated(.signedIn(userID: "alice")),
            draft
        )
        XCTAssertNil(continuation.takeIfAuthenticated(.signedIn(userID: "alice")))
    }

    func testCoreModelsRoundTripThroughCodable() throws {
        try assertRoundTrip(makeClinic())
        try assertRoundTrip(makeReview())
        try assertRoundTrip(makeUserProfile())
        try assertRoundTrip(makeProduct())
        try assertRoundTrip(makeQuote())
        try assertRoundTrip(makeInsurance())
    }

    func testClinicFavoritesNormalizesPersistsAndCapsAccountList() {
        let oversized = (0...ClinicFavorites.maximumCount).map { "clinic-\($0)" }
        let normalized = ClinicFavorites.normalized(
            [" clinic-a ", "clinic-a", "-unsafe", "unsafe/id"] + oversized
        )

        XCTAssertEqual(normalized.first, "clinic-a")
        XCTAssertEqual(normalized.count, ClinicFavorites.maximumCount)
        XCTAssertFalse(normalized.contains("-unsafe"))
        XCTAssertFalse(normalized.contains("unsafe/id"))
        XCTAssertFalse(ClinicFavorites.isValidClinicID("clinic-a\n"))
        XCTAssertEqual(
            ClinicFavorites.decode(ClinicFavorites.encode(normalized)),
            normalized
        )
        XCTAssertEqual(ClinicFavorites.decode("not-json"), [])
    }

    func testClinicFavoritesSettingIsStableAndReversible() {
        let original = ["clinic-a", "clinic-b"]
        XCTAssertEqual(
            ClinicFavorites.setting("clinic-c", isFavorite: true, in: original),
            ["clinic-a", "clinic-b", "clinic-c"]
        )
        XCTAssertEqual(
            ClinicFavorites.setting("clinic-a", isFavorite: true, in: original),
            original
        )
        XCTAssertEqual(
            ClinicFavorites.setting("clinic-a", isFavorite: false, in: original),
            ["clinic-b"]
        )
        XCTAssertEqual(
            ClinicFavorites.setting("bad/id", isFavorite: true, in: original),
            original
        )
    }

    func testSavedCatalogItemsClassifiesAndNormalizesCanonicalIDs() {
        let normalized = SavedCatalogItems.normalized(
            [
                " hk-service-grm-001 ",
                "hk-service-grm-001",
                "insurance-hk-fwd",
                "product-fish-oil",
                "insurance-hk-bad/value"
            ] + SavedCatalogItems.allowedItemIDs
        )

        XCTAssertEqual(normalized.first, "hk-service-grm-001")
        XCTAssertEqual(normalized[1], "insurance-hk-fwd")
        let catalogIDs: (String, [Int]) -> [String] = { prefix, numbers in
            numbers.map { "hk-service-\(prefix)-\(String(format: "%03d", $0))" }
        }
        let expectedCatalogIDs = catalogIDs(
            "sup",
            Array(1...12) + [17] + Array(19...33) + Array(41...62)
        ) + catalogIDs(
            "grm",
            Array(1...28) + Array(35...56)
        ) + catalogIDs(
            "fun",
            Array(1...24)
        ) + [
            "insurance-hk-fwd",
            "insurance-hk-onedegree",
            "insurance-hk-bluecross"
        ]
        XCTAssertEqual(SavedCatalogItems.allowedItemIDs, expectedCatalogIDs)
        XCTAssertEqual(normalized.count, SavedCatalogItems.allowedItemIDs.count)
        XCTAssertLessThanOrEqual(normalized.count, SavedCatalogItems.maximumCount)
        XCTAssertEqual(SavedCatalogItems.kind(for: normalized[0]), .service)
        XCTAssertEqual(SavedCatalogItems.kind(for: normalized[1]), .insurance)
        XCTAssertNil(SavedCatalogItems.kind(for: "hk-service-grm-001\n"))
        XCTAssertNil(SavedCatalogItems.kind(for: "hk-service-sup-013"))
        XCTAssertNil(SavedCatalogItems.kind(for: "product-fish-oil"))
        XCTAssertEqual(
            SavedCatalogItems.decode(SavedCatalogItems.encode(normalized)),
            normalized
        )
        XCTAssertEqual(SavedCatalogItems.decode("not-json"), [])
        XCTAssertEqual(
            SavedCatalogItems.normalizedStored([
                " product-fish-oil ",
                " product-fish-oil ",
                "hk-service-sup-001"
            ]),
            [" product-fish-oil ", "hk-service-sup-001"]
        )
        XCTAssertEqual(
            SavedCatalogItems.setting(
                " product-fish-oil ",
                isSaved: false,
                in: [" product-fish-oil ", "hk-service-sup-001"]
            ),
            ["hk-service-sup-001"]
        )
        XCTAssertEqual(
            SavedCatalogItems.rollingBack(
                " legacy-product ",
                attemptedSave: false,
                previousItemIDs: [" legacy-product ", "hk-service-sup-001"],
                currentItemIDs: ["hk-service-sup-001", "hk-service-grm-001"]
            ),
            [" legacy-product ", "hk-service-sup-001", "hk-service-grm-001"]
        )
    }

    func testSavedCatalogItemsSettingIsStableAndReversible() {
        let original = ["hk-service-sup-001", "insurance-hk-fwd"]
        XCTAssertEqual(
            SavedCatalogItems.setting(
                "hk-service-grm-002",
                isSaved: true,
                in: original
            ),
            original + ["hk-service-grm-002"]
        )
        XCTAssertEqual(
            SavedCatalogItems.setting(
                "insurance-hk-fwd",
                isSaved: true,
                in: original
            ),
            original
        )
        XCTAssertEqual(
            SavedCatalogItems.setting(
                "hk-service-sup-001",
                isSaved: false,
                in: original
            ),
            ["insurance-hk-fwd"]
        )
        XCTAssertEqual(
            SavedCatalogItems.setting("unsafe/id", isSaved: true, in: original),
            original
        )

        let twoConcurrentAdds = SavedCatalogItems.setting(
            "hk-service-grm-002",
            isSaved: true,
            in: SavedCatalogItems.setting(
                "hk-service-grm-001",
                isSaved: true,
                in: []
            )
        )
        XCTAssertEqual(
            SavedCatalogItems.setting(
                "hk-service-grm-001",
                isSaved: false,
                in: twoConcurrentAdds
            ),
            ["hk-service-grm-002"],
            "rolling back one failed item must preserve another successful item"
        )
    }

    func testSavedCatalogItemsRejectsStaleAccountSnapshots() {
        XCTAssertTrue(
            SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: "alice",
                expectedGeneration: 4,
                currentGeneration: 4
            )
        )
        XCTAssertFalse(
            SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: "bob",
                expectedGeneration: 4,
                currentGeneration: 4
            )
        )
        XCTAssertFalse(
            SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: "alice",
                expectedGeneration: 3,
                currentGeneration: 4
            )
        )
        XCTAssertFalse(
            SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: nil,
                expectedGeneration: 4,
                currentGeneration: 4
            )
        )
    }

    func testChatConversationIDIsDeterministicAndRejectsUnsafeParticipants() {
        XCTAssertEqual(
            ChatConversationID.make("bob", "alice"),
            "alice--bob"
        )
        XCTAssertEqual(
            ChatConversationID.make("alice", "bob"),
            "alice--bob"
        )
        XCTAssertNil(ChatConversationID.make("alice", "alice"))
        XCTAssertNil(ChatConversationID.make("alice", "unsafe/user"))
        XCTAssertNil(ChatConversationID.make("", "bob"))
        XCTAssertTrue(ChatConversationID.isSafeDocumentID(String(repeating: "r", count: 200)))
        XCTAssertFalse(ChatConversationID.isSafeDocumentID(String(repeating: "r", count: 201)))
        XCTAssertFalse(ChatConversationID.isSafeDocumentID("-review"))
    }

    func testChatModelsRoundTripThroughCodable() throws {
        let conversation = ChatConversation(
            id: "alice--bob",
            participantIds: ["alice", "bob"],
            participantNames: ["alice": "Alice", "bob": "Bob"],
            sourceReviewId: "review-1",
            lastMessageId: "message-1",
            lastMessage: "你好",
            lastMessageAt: date,
            lastSenderId: "alice",
            createdAt: date,
            updatedAt: date
        )
        let message = ChatMessage(
            id: "message-1",
            conversationId: conversation.id,
            senderId: "alice",
            body: "你好",
            sentAt: date,
            isDeleted: false
        )

        try assertRoundTrip(conversation)
        try assertRoundTrip(message)
        XCTAssertEqual(conversation.otherUserID(for: "alice"), "bob")
        XCTAssertEqual(conversation.otherDisplayName(for: "alice"), "Bob")
        XCTAssertEqual(conversation.sourceReviewId, "review-1")
    }

    func testChatConversationRejectsNonParticipantsAndMalformedMembership() {
        let conversation = ChatConversation(
            id: "alice--bob",
            participantIds: ["alice", "bob"],
            participantNames: ["alice": "Alice", "bob": "Bob"],
            lastMessageId: "message-1",
            lastMessage: "你好",
            lastMessageAt: date,
            lastSenderId: "alice",
            createdAt: date,
            updatedAt: date
        )

        XCTAssertNil(conversation.otherUserID(for: "mallory"))

        var duplicate = conversation
        duplicate.participantIds = ["alice", "alice"]
        XCTAssertNil(duplicate.otherUserID(for: "alice"))

        var oversized = conversation
        oversized.participantIds = ["alice", "bob", "mallory"]
        XCTAssertNil(oversized.otherUserID(for: "alice"))
    }

    func testChatMessageWindowPresentsNewestWindowChronologically() {
        let old = ChatMessage(
            id: "message-old",
            conversationId: "alice--bob",
            senderId: "alice",
            body: "舊訊息",
            sentAt: date.addingTimeInterval(-60),
            isDeleted: false
        )
        let sameTimeB = ChatMessage(
            id: "message-b",
            conversationId: "alice--bob",
            senderId: "bob",
            body: "同一時間 B",
            sentAt: date,
            isDeleted: false
        )
        let sameTimeA = ChatMessage(
            id: "message-a",
            conversationId: "alice--bob",
            senderId: "alice",
            body: "同一時間 A",
            sentAt: date,
            isDeleted: false
        )

        XCTAssertTrue(ChatMessageWindow.fetchesNewestFirst)
        XCTAssertEqual(ChatMessageWindow.maximumCount, 200)
        XCTAssertEqual(
            ChatMessageWindow.chronological([sameTimeB, old, sameTimeA]).map(\.id),
            ["message-old", "message-a", "message-b"]
        )
    }

    func testLocationButtonPolicyOnlyPromptsFromUndeterminedState() {
        XCTAssertEqual(
            LocationButtonPolicy.outcome(for: .notDetermined),
            .requestedPermission
        )
        XCTAssertEqual(
            LocationButtonPolicy.outcome(for: .authorized),
            .requestedLocation
        )
        XCTAssertEqual(
            LocationButtonPolicy.outcome(for: .denied),
            .requiresSettings
        )
        XCTAssertEqual(
            LocationButtonPolicy.outcome(for: .restricted),
            .requiresSettings
        )
    }

    func testClinicWithoutCoordinateRoundTripsAndHasNoMapLocation() throws {
        let clinic = makeClinic(id: "directory-only-clinic", coordinate: nil)

        try assertRoundTrip(clinic)
        XCTAssertNil(clinic.mapCoordinate)
        XCTAssertEqual(clinic.distanceText(from: nil), "位置待確認")
    }

    func testClinicOutsideHongKongNeverBecomesMapLocation() {
        let clinic = makeClinic(
            id: "invalid-map-clinic",
            coordinate: ClinicCoordinate(latitude: 25.0381, longitude: 121.5432)
        )

        XCTAssertFalse(clinic.hasReliableHongKongCoordinate)
        XCTAssertNil(clinic.mapCoordinate)
        XCTAssertEqual(clinic.distanceText(from: nil), "位置待確認")
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
        let viewModel = makeValidAddClinicViewModel()
        viewModel.name = "空網站診所"
        viewModel.website = "   "

        let clinic = viewModel.makeClinic()

        XCTAssertNil(clinic?.website)
    }

    @MainActor
    func testAddClinicViewModelRequiresResolvedHongKongCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .hongKong

        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertNil(viewModel.makeClinic())
    }

    @MainActor
    func testAddClinicViewModelUsesCustomCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .custom
        viewModel.latitude = "22.281123"
        viewModel.longitude = "114.158988"

        let clinic = viewModel.makeClinic()

        XCTAssertEqual(clinic?.coordinate?.latitude, 22.281123)
        XCTAssertEqual(clinic?.coordinate?.longitude, 114.158988)
    }

    @MainActor
    func testAddClinicViewModelRejectsInvalidCustomCoordinate() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.selectedRegion = .custom
        viewModel.latitude = "25.0381"
        viewModel.longitude = "121.5432"

        XCTAssertFalse(viewModel.canSubmit)
        XCTAssertNil(viewModel.makeClinic())
    }

    func testClinicSearchFilterMatchesNameAddressServicesAndTags() {
        var filter = ClinicSearchFilter()
        filter.query = "牙科"

        let byName = makeClinic(id: "by-name", name: "牙科專門動物醫院", services: ["一般診療"], tags: [])
        let byService = makeClinic(id: "by-service", name: "平安動物醫院", services: ["牙科"], tags: [])
        let byTag = makeClinic(id: "by-tag", name: "康寧動物醫院", services: ["一般診療"], tags: ["牙科"])
        let noMatch = makeClinic(id: "no-match", name: "希望動物醫院", services: ["一般診療"], tags: ["急診"])

        let results = filter.results(from: [noMatch, byTag, byService, byName])

        XCTAssertEqual(Set(results.map(\.id)), ["by-name", "by-service", "by-tag"])
    }

    func testClinicSearchFilterCombinesRegionAndPriceWithoutVerificationClaims() {
        var filter = ClinicSearchFilter()
        filter.region = .hongKong
        filter.price = .premium

        let match = makeClinic(id: "hk-premium", address: "香港中環德輔道中1號", priceLevel: 3, verified: true)
        let unverified = makeClinic(id: "hk-unverified", address: "香港灣仔軒尼詩道2號", priceLevel: 3, verified: false)
        let cheap = makeClinic(id: "hk-cheap", address: "香港旺角彌敦道3號", priceLevel: 2, verified: true)
        let overseas = makeClinic(
            id: "overseas-premium",
            address: "海外地址",
            coordinate: ClinicCoordinate(latitude: 25.0381, longitude: 121.5432),
            priceLevel: 3,
            verified: true
        )

        let results = filter.results(from: [overseas, cheap, unverified, match])

        XCTAssertEqual(Set(results.map(\.id)), ["hk-premium", "hk-unverified"])
    }

    func testAvailabilityFilterAndDefaultSortPrioritizeOpenClinics() {
        let now = Date(timeIntervalSince1970: 1_775_102_400) // 2026-04-02 12:00 HKT
        let alwaysOpen = makeClinic(
            id: "always-open",
            name: "24 小時動物醫院",
            availability: makeAvailability(is24Hours: true)
        )
        let unknown = makeClinic(id: "unknown-hours", name: "未知時間診所")
        var filter = ClinicSearchFilter()

        XCTAssertEqual(
            filter.results(from: [unknown, alwaysOpen], at: now).map(\.id),
            ["always-open", "unknown-hours"]
        )

        filter.availability = .open24Hours
        XCTAssertEqual(
            filter.results(from: [unknown, alwaysOpen], at: now).map(\.id),
            ["always-open"]
        )

        filter.availability = .nightService
        XCTAssertEqual(
            filter.results(from: [unknown, alwaysOpen], at: now).map(\.id),
            ["always-open"]
        )
    }

    func testUrgentClinicOrderingPrioritizesAvailabilityThenKnownDistance() {
        let now = Date(timeIntervalSince1970: 1_775_102_400) // 2026-04-02 12:00 HKT
        let guardianLocation = CLLocation(latitude: 22.3193, longitude: 114.1694)
        let alwaysOpen = makeClinic(
            id: "always-open",
            name: "24 小時診所",
            coordinate: ClinicCoordinate(latitude: 22.50, longitude: 114.30),
            availability: makeAvailability(is24Hours: true)
        )
        let nearUnknown = makeClinic(
            id: "near-unknown",
            name: "附近診所",
            coordinate: ClinicCoordinate(latitude: 22.3194, longitude: 114.1694)
        )
        let farUnknown = makeClinic(
            id: "far-unknown",
            name: "較遠診所",
            coordinate: ClinicCoordinate(latitude: 22.40, longitude: 114.25)
        )
        let listOnlyAlpha = makeClinic(
            id: "list-only-alpha",
            name: "A 列表診所",
            coordinate: nil
        )
        let listOnlyZulu = makeClinic(
            id: "list-only-zulu",
            name: "Z 列表診所",
            coordinate: nil
        )

        let ordered = urgentClinicOrdering(
            [listOnlyZulu, farUnknown, listOnlyAlpha, alwaysOpen, nearUnknown],
            from: guardianLocation,
            at: now
        )

        XCTAssertEqual(
            ordered.map(\.id),
            ["always-open", "near-unknown", "far-unknown", "list-only-alpha", "list-only-zulu"]
        )
    }

    @MainActor
    func testUrgentActivationSelectsFirstRankedClinicInsteadOfOldSelection() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let alwaysOpen = makeClinic(
            id: "always-open",
            availability: makeAvailability(is24Hours: true)
        )
        let unknownHours = makeClinic(id: "unknown-hours", name: "未知時間診所")
        let viewModel = MapViewModel(
            testingClinics: [unknownHours, alwaysOpen],
            at: now
        )
        viewModel.selectedClinicID = unknownHours.id

        viewModel.activateUrgentMode()

        XCTAssertEqual(viewModel.selectedClinicID, alwaysOpen.id)
    }

    @MainActor
    func testUrgentLocationRerankingSelectsFirstClinicOnlyWhenItChanges() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let farAlphabetical = makeClinic(
            id: "far-alphabetical",
            name: "A 較遠診所",
            coordinate: ClinicCoordinate(latitude: 22.50, longitude: 114.30)
        )
        let nearLaterName = makeClinic(
            id: "near-later-name",
            name: "Z 附近診所",
            coordinate: ClinicCoordinate(latitude: 22.3194, longitude: 114.1694)
        )
        let viewModel = MapViewModel(
            testingClinics: [nearLaterName, farAlphabetical],
            at: now
        )

        viewModel.activateUrgentMode()
        XCTAssertEqual(viewModel.selectedClinicID, farAlphabetical.id)

        viewModel.updateContextualLocation(
            CLLocation(latitude: 22.3193, longitude: 114.1694)
        )
        XCTAssertEqual(viewModel.selectedClinicID, nearLaterName.id)

        viewModel.updateContextualLocation(
            CLLocation(latitude: 22.3193, longitude: 114.1694)
        )
        XCTAssertEqual(viewModel.selectedClinicID, nearLaterName.id)
    }

    func testAvailabilityFilterLimitationMessageAppearsOnlyForActiveFilters() {
        let message = "只按有現行官方營業資料的診所篩選；未列出的診所不代表休息，出發前請先致電。"

        XCTAssertNil(ClinicSearchFilter.Availability.all.limitationMessage)
        XCTAssertEqual(ClinicSearchFilter.Availability.openNow.limitationMessage, message)
        XCTAssertEqual(ClinicSearchFilter.Availability.open24Hours.limitationMessage, message)
        XCTAssertEqual(ClinicSearchFilter.Availability.nightService.limitationMessage, message)
    }

    func testDecodeFirestoreDocumentsSkipsMalformedDocumentsInOriginalOrder() throws {
        let documents = ["valid-A", "malformed", "valid-B"]
        var failedDocumentIDs: [String] = []

        let decoded = try decodeFirestoreDocuments(
            documents,
            documentID: { $0 },
            decode: { document in
                guard document != "malformed" else {
                    throw NSError(domain: "VetMapTests", code: 1)
                }
                return document
            },
            onFailure: { documentID, _ in
                failedDocumentIDs.append(documentID)
            }
        )

        XCTAssertEqual(decoded, ["valid-A", "valid-B"])
        XCTAssertEqual(failedDocumentIDs, ["malformed"])
    }

    func testDecodeFirestoreDocumentsReturnsEmptyWithoutFailureCallback() throws {
        var failureCount = 0

        let decoded: [String] = try decodeFirestoreDocuments(
            [String](),
            documentID: { $0 },
            decode: { $0 },
            onFailure: { _, _ in
                failureCount += 1
            }
        )

        XCTAssertEqual(decoded, [])
        XCTAssertEqual(failureCount, 0)
    }

    func testDecodeFirestoreDocumentsThrowsFirstErrorAfterReportingAllFailures() {
        let documents = ["malformed-A", "malformed-B"]
        var failedDocumentIDs: [String] = []

        XCTAssertThrowsError(
            try decodeFirestoreDocuments(
                documents,
                documentID: { $0 },
                decode: { document in
                    throw NSError(
                        domain: "VetMapTests",
                        code: document == "malformed-A" ? 1 : 2
                    )
                },
                onFailure: { documentID, _ in
                    failedDocumentIDs.append(documentID)
                }
            ) as [String]
        ) { error in
            XCTAssertEqual((error as NSError).code, 1)
        }

        XCTAssertEqual(failedDocumentIDs, documents)
    }

    func testRegularHoursComputeOpenNowInHongKongTime() {
        let thursdayNoon = Date(timeIntervalSince1970: 1_775_102_400)
        let thursdayAfterClose = Date(timeIntervalSince1970: 1_775_134_800)
        let clinic = makeClinic(
            availability: makeAvailability(
                weeklyHours: [
                    "thu": [
                        ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")
                    ]
                ]
            )
        )

        XCTAssertTrue(clinic.isOpen(at: thursdayNoon))
        XCTAssertEqual(
            clinic.availabilityLabel(at: thursdayNoon),
            "營業中 · 至 20:00"
        )

        XCTAssertEqual(clinic.operatingStatus(at: thursdayAfterClose), .closed)
        XCTAssertFalse(clinic.isOpen(at: thursdayAfterClose))
        XCTAssertEqual(clinic.availabilityLabel(at: thursdayAfterClose), "休息中")
    }

    func testNextOpeningHandlesSplitDaysAndStrictFutureStarts() {
        let reference = Date(timeIntervalSince1970: 1_775_102_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let thursday = calendar.startOfDay(for: reference)
        func date(dayOffset: Int, minute: Int) -> Date {
            calendar.date(
                byAdding: .minute,
                value: dayOffset * 24 * 60 + minute,
                to: thursday
            )!
        }
        let verifiedAt = date(dayOffset: -1, minute: 0)
        let expiresAt = date(dayOffset: 30, minute: 0)
        let split = makeAvailability(
            weeklyHours: [
                "thu": [
                    ClinicHoursInterval(opensAt: "09:00", closesAt: "13:00"),
                    ClinicHoursInterval(opensAt: "14:00", closesAt: "19:00")
                ]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
        let clinic = makeClinic(availability: split)

        XCTAssertEqual(
            split.nextOpening(at: date(dayOffset: 0, minute: 8 * 60 + 59)),
            date(dayOffset: 0, minute: 9 * 60)
        )
        XCTAssertEqual(
            split.nextOpening(at: date(dayOffset: 0, minute: 13 * 60 + 30)),
            date(dayOffset: 0, minute: 14 * 60)
        )
        XCTAssertEqual(
            clinic.availabilityLabel(at: date(dayOffset: 0, minute: 13 * 60 + 30)),
            "休息中 · 預計今日 14:00 再開"
        )
        XCTAssertEqual(
            split.nextOpening(at: date(dayOffset: 0, minute: 14 * 60)),
            date(dayOffset: 7, minute: 9 * 60)
        )

        let tomorrow = makeAvailability(
            weeklyHours: [
                "fri": [ClinicHoursInterval(opensAt: "08:00", closesAt: "18:00")]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
        XCTAssertEqual(
            makeClinic(availability: tomorrow).availabilityLabel(
                at: date(dayOffset: 0, minute: 20 * 60)
            ),
            "休息中 · 預計明日 08:00 再開"
        )

        let nextWednesday = makeAvailability(
            weeklyHours: [
                "wed": [ClinicHoursInterval(opensAt: "10:00", closesAt: "18:00")]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
        XCTAssertEqual(
            makeClinic(availability: nextWednesday).availabilityLabel(
                at: date(dayOffset: 0, minute: 20 * 60)
            ),
            "休息中 · 預計星期三 10:00 再開"
        )
    }

    func testNextOpeningHandlesCrossWeekOvernightEmptyAndExpiry() {
        let reference = Date(timeIntervalSince1970: 1_775_102_400)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let thursday = calendar.startOfDay(for: reference)
        func date(dayOffset: Int, minute: Int) -> Date {
            calendar.date(
                byAdding: .minute,
                value: dayOffset * 24 * 60 + minute,
                to: thursday
            )!
        }
        let verifiedAt = date(dayOffset: -1, minute: 0)
        let expiresAt = date(dayOffset: 30, minute: 0)

        let crossWeek = makeAvailability(
            weeklyHours: [
                "sun": [ClinicHoursInterval(opensAt: "10:00", closesAt: "16:00")]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
        XCTAssertEqual(
            crossWeek.nextOpening(at: date(dayOffset: 2, minute: 20 * 60)),
            date(dayOffset: 3, minute: 10 * 60)
        )

        let overnight = makeAvailability(
            weeklyHours: [
                "wed": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
            ],
            offersNightService: true,
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
        XCTAssertEqual(
            overnight.nextOpening(at: date(dayOffset: 0, minute: 60)),
            date(dayOffset: 6, minute: 21 * 60)
        )
        XCTAssertEqual(
            makeClinic(availability: overnight).availabilityLabel(
                at: date(dayOffset: 0, minute: 3 * 60)
            ),
            "設夜診"
        )

        XCTAssertNil(
            makeAvailability(
                verifiedAt: verifiedAt,
                expiresAt: expiresAt
            ).nextOpening(at: reference)
        )
        XCTAssertNil(
            makeAvailability(
                is24Hours: true,
                verifiedAt: verifiedAt,
                expiresAt: expiresAt
            ).nextOpening(at: reference)
        )
        XCTAssertNil(
            makeAvailability(
                timeZoneIdentifier: "Asia/Taipei",
                verifiedAt: verifiedAt,
                expiresAt: expiresAt
            ).nextOpening(at: reference)
        )

        let expiryAtOpening = date(dayOffset: 1, minute: 8 * 60)
        let expiresAtCandidate = makeAvailability(
            weeklyHours: [
                "fri": [ClinicHoursInterval(opensAt: "08:00", closesAt: "18:00")]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiryAtOpening
        )
        XCTAssertNil(
            expiresAtCandidate.nextOpening(at: date(dayOffset: 0, minute: 20 * 60))
        )

        let expiresAfterCandidate = makeAvailability(
            weeklyHours: [
                "fri": [ClinicHoursInterval(opensAt: "08:00", closesAt: "18:00")]
            ],
            verifiedAt: verifiedAt,
            expiresAt: expiryAtOpening.addingTimeInterval(1)
        )
        XCTAssertEqual(
            expiresAfterCandidate.nextOpening(at: date(dayOffset: 0, minute: 20 * 60)),
            expiryAtOpening
        )
        XCTAssertNil(expiresAfterCandidate.nextOpening(at: expiresAfterCandidate.expiresAt))
    }

    func testClinicDuplicateMatcherNormalizesHongKongIdentityFieldsAndDistance() throws {
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("＋８５２　２１２３－４５６７"),
            ["21234567"]
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("00852 2123/4567"),
            ["21234567"]
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("2123/4567"),
            ["21234567"]
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("2698 2185 / 2687 0226"),
            ["26982185", "26870226"]
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("2653 3632 / 6168 6175"),
            ["26533632", "61686175"]
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.canonicalPhones("28828123/62158608"),
            ["28828123", "62158608"]
        )
        XCTAssertTrue(ClinicDuplicateMatcher.canonicalPhones("123").isEmpty)
        XCTAssertEqual(
            ClinicDuplicateMatcher.normalizedText(" ＨＡＰＰＹ－Pet！診所 "),
            "happypet診所"
        )
        XCTAssertEqual(
            ClinicDuplicateMatcher.normalizedText("香港．中環，皇后大道中 １ 號"),
            "香港中環皇后大道中1號"
        )

        let origin = ClinicCoordinate(latitude: 22.3000, longitude: 114.2000)
        let nearby = ClinicCoordinate(latitude: 22.3005, longitude: 114.2000)
        let far = ClinicCoordinate(latitude: 22.3030, longitude: 114.2000)
        XCTAssertLessThan(
            try XCTUnwrap(ClinicDuplicateMatcher.distanceMeters(from: origin, to: nearby)),
            100
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(ClinicDuplicateMatcher.distanceMeters(from: origin, to: far)),
            200
        )
        XCTAssertNil(ClinicDuplicateMatcher.distanceMeters(from: nil, to: nearby))
    }

    func testClinicDuplicateMatcherUsesOnlyStrongDirectBranches() {
        let origin = ClinicCoordinate(latitude: 22.3000, longitude: 114.2000)
        let within100 = ClinicCoordinate(latitude: 22.3005, longitude: 114.2000)
        let within200 = ClinicCoordinate(latitude: 22.3015, longitude: 114.2000)
        let far = ClinicCoordinate(latitude: 22.3030, longitude: 114.2000)
        var draft = makeClinic(
            id: "draft",
            name: "Happy Pet 診所",
            address: "香港中環皇后大道中1號",
            coordinate: origin
        )
        draft.phone = "+852 2123 4567"

        var phoneAndName = makeClinic(
            id: "phone-name",
            name: "ＨＡＰＰＹ－ＰＥＴ 診所！",
            address: "九龍遠處",
            coordinate: far
        )
        phoneAndName.phone = "２１２３－４５６７"
        XCTAssertEqual(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: phoneAndName),
            .samePhoneAndName
        )

        var phoneNearby = makeClinic(
            id: "phone-nearby",
            name: "另一間獸醫",
            address: "另一地址",
            coordinate: within200
        )
        phoneNearby.phone = "21234567"
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: draft,
            and: phoneNearby
        ) else {
            return XCTFail("same phone within 200m must match")
        }

        var nameAndAddress = makeClinic(
            id: "name-address",
            name: "happy—pet 診所",
            address: "香港中環；皇后大道中１號",
            coordinate: far
        )
        nameAndAddress.phone = ""
        XCTAssertEqual(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: nameAndAddress),
            .sameNameAndAddress
        )

        var nameNearby = makeClinic(
            id: "name-nearby",
            name: "HAPPY PET 診所",
            address: "不同地址",
            coordinate: within100
        )
        nameNearby.phone = "87654321"
        guard case .sameNameNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: draft,
            and: nameNearby
        ) else {
            return XCTFail("same name within 100m must match")
        }

        var phoneFar = makeClinic(
            id: "phone-far",
            name: "不同名稱",
            address: "不同地址",
            coordinate: far
        )
        phoneFar.phone = "21234567"
        var nameFar = makeClinic(
            id: "name-far",
            name: "Happy Pet 診所",
            address: "不同地址",
            coordinate: far
        )
        nameFar.phone = "87654321"
        XCTAssertNil(ClinicDuplicateMatcher.strongMatchReason(between: draft, and: phoneFar))

        var multiPhoneDraft = makeClinic(
            id: "multi-phone-draft",
            name: "多電話診所",
            address: "香港中環測試地址",
            coordinate: origin
        )
        multiPhoneDraft.phone = "2698 2185 / 2687 0226"
        var firstPhoneNearby = makeClinic(
            id: "first-phone",
            name: "另一名稱一",
            address: "另一地址一",
            coordinate: within200
        )
        firstPhoneNearby.phone = "2698 2185"
        var secondPhoneNearby = makeClinic(
            id: "second-phone",
            name: "另一名稱二",
            address: "另一地址二",
            coordinate: within200
        )
        secondPhoneNearby.phone = "2687 0226"
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: multiPhoneDraft,
            and: firstPhoneNearby
        ) else {
            return XCTFail("first phone in a production multi-number field must match")
        }
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: multiPhoneDraft,
            and: secondPhoneNearby
        ) else {
            return XCTFail("second phone in a production multi-number field must match")
        }

        XCTAssertNil(ClinicDuplicateMatcher.strongMatchReason(between: draft, and: nameFar))
        XCTAssertNil(ClinicDuplicateMatcher.firstStrongMatch(for: draft, in: [nameFar, phoneFar]))

        var insufficientDraft = makeClinic(
            id: "insufficient-draft",
            name: "只得名稱",
            address: "",
            coordinate: nil
        )
        insufficientDraft.phone = ""
        var insufficientExisting = makeClinic(
            id: "insufficient-existing",
            name: "只得名稱",
            address: "",
            coordinate: nil
        )
        insufficientExisting.phone = ""
        XCTAssertNil(
            ClinicDuplicateMatcher.firstStrongMatch(
                for: insufficientDraft,
                in: [insufficientExisting]
            )
        )

        XCTAssertEqual(
            ClinicDuplicateMatcher.duplicateCandidates(
                from: [draft, phoneAndName, phoneNearby],
                excludingRemovedClinicIDs: [phoneAndName.id]
            ).map(\.id),
            [draft.id, phoneNearby.id]
        )
    }

    func testClinicDuplicateCandidatesIgnoreDisplayFiltersAndExcludeRemovedClinics() {
        let searchHidden = makeClinic(
            id: "search-hidden",
            name: "安心動物醫院",
            address: "香港中環測試地址"
        )
        let availabilityHidden = makeClinic(
            id: "availability-hidden",
            name: "夜診候選",
            address: "香港九龍測試地址",
            availability: nil
        )
        let mapHidden = makeClinic(
            id: "map-hidden",
            name: "座標待確認候選",
            address: "香港新界測試地址",
            coordinate: nil,
            catalogRegion: "HK"
        )
        let moderationRemoved = makeClinic(
            id: "moderation-removed",
            name: "已移除診所",
            address: "香港測試地址"
        )
        let rawClinics = [searchHidden, availabilityHidden, mapHidden, moderationRemoved]
        var activeDisplayFilter = ClinicSearchFilter()
        activeDisplayFilter.query = "完全不相符"
        activeDisplayFilter.availability = .open24Hours

        XCTAssertTrue(activeDisplayFilter.results(from: rawClinics).isEmpty)
        XCTAssertNil(mapHidden.coordinate)
        XCTAssertEqual(
            ClinicDuplicateMatcher.duplicateCandidates(
                from: rawClinics,
                excludingRemovedClinicIDs: [moderationRemoved.id]
            ).map(\.id),
            [searchHidden.id, availabilityHidden.id, mapHidden.id]
        )
    }

    func testClinicDuplicateSubmissionGateConfirmsAndSubmitsDraftOnlyOnce() {
        let coordinate = ClinicCoordinate(latitude: 22.3000, longitude: 114.2000)
        let draft = makeClinic(
            id: "draft",
            name: "安心動物醫院",
            address: "香港旺角彌敦道1號",
            coordinate: coordinate
        )
        let existing = makeClinic(
            id: "existing",
            name: "安心動物醫院",
            address: "香港旺角彌敦道1號",
            coordinate: coordinate
        )
        var gate = ClinicDuplicateSubmissionGate()

        guard case let .requiresConfirmation(match) = gate.decision(
            for: draft,
            existingClinics: [existing]
        ) else {
            return XCTFail("first strong match must preserve draft for confirmation")
        }
        XCTAssertEqual(match.clinic.id, existing.id)
        gate.confirmDifferentClinic(draft)
        XCTAssertEqual(gate.decision(for: draft, existingClinics: [existing]), .submit)
        XCTAssertTrue(gate.beginSubmission(draft))
        XCTAssertFalse(gate.beginSubmission(draft))
        XCTAssertEqual(
            gate.decision(for: draft, existingClinics: [existing]),
            .alreadySubmitted
        )

        gate.finishSubmission(draft, succeeded: false)
        XCTAssertEqual(gate.decision(for: draft, existingClinics: [existing]), .submit)
        XCTAssertTrue(gate.beginSubmission(draft))
        gate.finishSubmission(draft, succeeded: true)
        XCTAssertEqual(
            gate.decision(for: draft, existingClinics: [existing]),
            .alreadySubmitted
        )

        XCTAssertEqual(
            ClinicDuplicateSubmissionGate().decision(
                for: draft,
                existingClinics: []
            ),
            .submit
        )

        var multiPhoneDraft = draft
        multiPhoneDraft.phone = "2698 2185 / 2687 0226"
        var reorderedPhoneDraft = multiPhoneDraft
        reorderedPhoneDraft.phone = "2687 0226 / 2698 2185"
        var sortedFingerprintGate = ClinicDuplicateSubmissionGate()
        sortedFingerprintGate.confirmDifferentClinic(multiPhoneDraft)
        XCTAssertEqual(
            sortedFingerprintGate.decision(
                for: reorderedPhoneDraft,
                existingClinics: [existing]
            ),
            .submit
        )
    }

    func testClinicDuplicateApprovalPolicyRequiresFreshExactCandidateOverride() {
        let origin = ClinicCoordinate(latitude: 22.3000, longitude: 114.2000)
        let far = ClinicCoordinate(latitude: 22.3030, longitude: 114.2000)
        var pending = makeClinic(
            id: "pending",
            name: "安心動物醫院",
            address: "香港旺角彌敦道1號",
            coordinate: origin
        )
        pending.phone = "21234567"
        var initialCandidate = makeClinic(
            id: "a-candidate",
            name: "安心動物醫院",
            address: "不同地址",
            coordinate: far
        )
        initialCandidate.phone = "21234567"
        var unrelated = makeClinic(
            id: "unrelated",
            name: "完全不同診所",
            address: "香港另一地址",
            coordinate: far
        )
        unrelated.phone = "99998888"

        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [unrelated],
                removedClinicIDs: []
            ),
            .approve
        )
        guard case let .requiresOverride(initialChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [initialCandidate],
                removedClinicIDs: []
            )
        else {
            return XCTFail("first fresh strong match must require an override")
        }
        XCTAssertEqual(initialChallenge.matches.map(\.clinic.id), [initialCandidate.id])
        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [initialCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint: initialChallenge.fingerprint
            ),
            .approve
        )

        var sameIDContentChanged = initialCandidate
        sameIDContentChanged.address = "再不同地址"
        guard case let .requiresOverride(contentChangedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [sameIDContentChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: initialChallenge.fingerprint
            )
        else {
            return XCTFail("same-ID normalized evidence change must invalidate the override")
        }
        XCTAssertEqual(contentChangedChallenge.matches.map(\.clinic.id), [initialCandidate.id])
        XCTAssertEqual(contentChangedChallenge.matches.first?.reason, .samePhoneAndName)
        XCTAssertNotEqual(contentChangedChallenge.fingerprint, initialChallenge.fingerprint)

        var sameIDReasonChanged = sameIDContentChanged
        sameIDReasonChanged.name = "另一名稱"
        sameIDReasonChanged.coordinate = ClinicCoordinate(
            latitude: 22.3010,
            longitude: 114.2000
        )
        guard case let .requiresOverride(reasonChangedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [sameIDReasonChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: contentChangedChallenge.fingerprint
            )
        else {
            return XCTFail("same-ID match-reason change must invalidate the override")
        }
        XCTAssertEqual(reasonChangedChallenge.matches.map(\.clinic.id), [initialCandidate.id])
        guard
            let reasonChangedMatch = reasonChangedChallenge.matches.first,
            case .samePhoneNearby = reasonChangedMatch.reason
        else {
            return XCTFail("same-ID candidate should now match by nearby phone")
        }
        XCTAssertNotEqual(reasonChangedChallenge.fingerprint, contentChangedChallenge.fingerprint)
        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [sameIDReasonChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: reasonChangedChallenge.fingerprint
            ),
            .approve
        )

        guard case let .requiresOverride(wrongOverrideChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [initialCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint: "wrong-fingerprint"
            )
        else {
            return XCTFail("an override for another candidate set must not approve")
        }
        XCTAssertEqual(wrongOverrideChallenge.matches.map(\.clinic.id), [initialCandidate.id])

        var changedCandidate = makeClinic(
            id: "changed-candidate",
            name: "安心動物醫院",
            address: "香港旺角彌敦道1號",
            coordinate: nil
        )
        changedCandidate.phone = "87654321"
        guard case let .requiresOverride(changedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [changedCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint: initialChallenge.fingerprint
            )
        else {
            return XCTFail("a stale override must reprompt for the fresh raw candidate")
        }
        XCTAssertEqual(changedChallenge.matches.map(\.clinic.id), [changedCandidate.id])
        XCTAssertNil(changedCandidate.coordinate)

        var addedCandidate = makeClinic(
            id: "z-candidate",
            name: "另一名稱",
            address: "另一地址",
            coordinate: ClinicCoordinate(latitude: 22.3010, longitude: 114.2000)
        )
        addedCandidate.phone = pending.phone
        guard case let .requiresOverride(expandedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [addedCandidate, initialCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint: initialChallenge.fingerprint
            )
        else {
            return XCTFail("adding a later candidate must invalidate the one-candidate override")
        }
        XCTAssertEqual(
            expandedChallenge.matches.map(\.clinic.id),
            [initialCandidate.id, addedCandidate.id]
        )
        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [addedCandidate, initialCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint: expandedChallenge.fingerprint
            ),
            .approve
        )

        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [initialCandidate],
                removedClinicIDs: [initialCandidate.id]
            ),
            .approve
        )

        var nameOnly = makeClinic(
            id: "name-only",
            name: pending.name,
            address: "不同地址",
            coordinate: far
        )
        nameOnly.phone = "87654321"
        var phoneOnly = makeClinic(
            id: "phone-only",
            name: "不同名稱",
            address: "另一地址",
            coordinate: far
        )
        phoneOnly.phone = pending.phone
        XCTAssertEqual(
            ClinicDuplicateApprovalPolicy.decision(
                for: pending,
                approvedClinics: [nameOnly, phoneOnly],
                removedClinicIDs: []
            ),
            .approve
        )
    }

    func testClinicDuplicateMatchReasonAdminReadableLabels() {
        XCTAssertEqual(
            ClinicDuplicateMatchReason.samePhoneAndName.adminReadableLabel,
            "相同電話及名稱"
        )
        XCTAssertEqual(
            ClinicDuplicateMatchReason.samePhoneNearby(distanceMeters: 42.6)
                .adminReadableLabel,
            "相同電話，距離約 43 米"
        )
        XCTAssertEqual(
            ClinicDuplicateMatchReason.sameNameAndAddress.adminReadableLabel,
            "相同名稱及地址"
        )
        XCTAssertEqual(
            ClinicDuplicateMatchReason.sameNameNearby(distanceMeters: 12.4)
                .adminReadableLabel,
            "相同名稱，距離約 12 米"
        )
    }

    func testClinicApprovalOperationPolicyKeepsAllFourOutcomesDistinct() {
        XCTAssertEqual(
            ClinicApprovalOperationPolicy.resolution(for: .preflightFailed),
            .preflightFailedNoWrite
        )
        XCTAssertEqual(
            ClinicApprovalOperationPolicy.resolution(for: .writeFailed),
            .writeFailedNoWrite
        )
        XCTAssertEqual(
            ClinicApprovalOperationPolicy.resolution(
                for: .writeSucceededRefreshSucceeded
            ),
            .approved
        )
        XCTAssertEqual(
            ClinicApprovalOperationPolicy.resolution(
                for: .writeSucceededRefreshFailed
            ),
            .approvedRefreshFailed
        )
    }

    func testClinicPublicationPolicyRetainsOnlySafeIdentityContactAndCoordinate() throws {
        let submitted = makeClinic(
            id: "client-controlled-id",
            name: "香港社群投稿診所",
            address: "香港測試地址",
            catalogRegion: "TW",
            services: ["24 小時急症", "夜診"],
            tags: ["官方", "已驗證"],
            priceLevel: 3,
            verified: true,
            availability: makeAvailability(is24Hours: true)
        )
        let projected = try XCTUnwrap(
            ClinicPublicationPolicy.safeProjection(
                of: submitted,
                submitterID: "firebase-user-1"
            )
        )

        XCTAssertEqual(projected.id, submitted.id)
        XCTAssertEqual(projected.name, submitted.name)
        XCTAssertEqual(projected.address, submitted.address)
        XCTAssertEqual(projected.coordinate, submitted.coordinate)
        XCTAssertEqual(projected.phone, submitted.phone)
        XCTAssertEqual(projected.website, submitted.website)
        XCTAssertEqual(projected.createdAt, submitted.createdAt)
        XCTAssertEqual(projected.updatedAt, submitted.updatedAt)
        XCTAssertEqual(projected.reportedBy, "firebase-user-1")
        XCTAssertEqual(projected.catalogRegion, "HK")
        XCTAssertFalse(projected.verified)
        XCTAssertTrue(projected.openingHours.isEmpty)
        XCTAssertNil(projected.availability)
        XCTAssertTrue(projected.services.isEmpty)
        XCTAssertEqual(projected.avgRating, 0)
        XCTAssertEqual(projected.reviewCount, 0)
        XCTAssertEqual(projected.priceLevel, 0)
        XCTAssertTrue(projected.images.isEmpty)
        XCTAssertTrue(projected.tags.isEmpty)
    }

    func testClinicPublicationPolicyRejectsMissingInvalidAndNonHongKongCoordinates() {
        let rejectedCoordinates: [ClinicCoordinate?] = [
            nil,
            ClinicCoordinate(latitude: .nan, longitude: 114.1),
            ClinicCoordinate(latitude: 22.3, longitude: .infinity),
            ClinicCoordinate(latitude: 25.033, longitude: 121.5654),
            ClinicCoordinate(latitude: 22.7, longitude: 114.2),
            ClinicCoordinate(latitude: 22.3, longitude: 113.7)
        ]

        for coordinate in rejectedCoordinates {
            XCTAssertNil(
                ClinicPublicationPolicy.safeProjection(
                    of: makeClinic(coordinate: coordinate),
                    submitterID: "firebase-user-1"
                )
            )
        }
    }

    func testOvernightHoursUsePreviousDaySchedule() {
        let thursdayOneAM = Date(timeIntervalSince1970: 1_775_062_800)
        let clinic = makeClinic(
            availability: makeAvailability(
                weeklyHours: [
                    "wed": [
                        ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")
                    ]
                ],
                offersNightService: true
            )
        )

        XCTAssertTrue(clinic.isOpen(at: thursdayOneAM))
        XCTAssertEqual(
            clinic.availabilityLabel(at: thursdayOneAM),
            "營業中 · 至 02:00"
        )
    }

    func testExpiredAvailabilityNeverClaimsOpen() {
        let afterExpiry = Date(timeIntervalSince1970: 1_777_766_400)
        let clinic = makeClinic(availability: makeAvailability(is24Hours: true))
        var filter = ClinicSearchFilter()
        filter.availability = .openNow

        XCTAssertFalse(clinic.isOpen(at: afterExpiry))
        XCTAssertEqual(clinic.operatingStatus(at: afterExpiry), .unavailable)
        XCTAssertNil(clinic.availabilityLabel(at: afterExpiry))
        XCTAssertTrue(filter.results(from: [clinic], at: afterExpiry).isEmpty)
    }

    func testCanonicalAvailabilitySemanticsAcceptSupportedSchedules() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let allDay = makeAvailability(is24Hours: true)
        let sevenDay = makeAvailability(weeklyHours: [
            "thu": [ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")]
        ])
        let trinitySplit = makeAvailability(weeklyHours: [
            "thu": [
                ClinicHoursInterval(opensAt: "09:00", closesAt: "13:00"),
                ClinicHoursInterval(opensAt: "14:00", closesAt: "19:00")
            ]
        ])
        let overnight = makeAvailability(weeklyHours: [
            "wed": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
        ], offersNightService: true)

        for availability in [allDay, sevenDay, trinitySplit, overnight] {
            XCTAssertTrue(availability.isCurrent(at: now))
        }
    }

    func testAvailabilityExpiryBoundaryIsFailClosed() {
        let verifiedAt = Date(timeIntervalSince1970: 1_775_000_000)
        let expiresAt = verifiedAt.addingTimeInterval(24 * 60 * 60)
        let availability = makeAvailability(
            is24Hours: true,
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )

        XCTAssertTrue(availability.isCurrent(at: verifiedAt))
        XCTAssertTrue(availability.isCurrent(at: expiresAt.addingTimeInterval(-1)))
        XCTAssertFalse(availability.isCurrent(at: expiresAt))

        let exactlyOneHundredDays = makeAvailability(
            is24Hours: true,
            verifiedAt: verifiedAt,
            expiresAt: verifiedAt.addingTimeInterval(100 * 24 * 60 * 60)
        )
        XCTAssertTrue(exactlyOneHundredDays.isCurrent(at: verifiedAt))
        assertInvalidAvailability(
            makeAvailability(
                is24Hours: true,
                verifiedAt: verifiedAt,
                expiresAt: verifiedAt.addingTimeInterval(100 * 24 * 60 * 60 + 1)
            ),
            at: verifiedAt,
            message: "100 days plus one second"
        )
    }

    func testInvalidAvailabilityMutationMatrixIsUnavailableAndExcludedFromFilters() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let validStart = Date(timeIntervalSince1970: 1_775_000_000)
        let validEnd = validStart.addingTimeInterval(90 * 24 * 60 * 60)
        let regularDay = [
            ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")
        ]
        let invalidPayloads = [
            makeAvailability(schemaVersion: 2, is24Hours: true),
            makeAvailability(migrationId: "", is24Hours: true),
            makeAvailability(migrationId: "other-hours-v1", is24Hours: true),
            makeAvailability(migrationId: "hk-clinic-hours-v1\u{2060}", is24Hours: true),
            makeAvailability(migrationId: "hk-clinic-hours-v1\u{FEFF}", is24Hours: true),
            makeAvailability(timeZoneIdentifier: "Asia/Taipei", is24Hours: true),
            makeAvailability(is24Hours: true, sourceURL: URL(string: "http://example.com")!),
            makeAvailability(is24Hours: true, sourceURL: URL(string: "https:///hours")!),
            makeAvailability(is24Hours: true, sourceName: " \n "),
            makeAvailability(is24Hours: true, sourceName: "\u{2060}"),
            makeAvailability(is24Hours: true, serviceNote: "\t"),
            makeAvailability(is24Hours: true, serviceNote: "\u{FEFF}"),
            makeAvailability(is24Hours: true, verifiedAt: validEnd, expiresAt: validStart),
            makeAvailability(is24Hours: true, verifiedAt: now.addingTimeInterval(1), expiresAt: validEnd),
            makeAvailability(is24Hours: true, verifiedAt: validStart, expiresAt: now),
            makeAvailability(
                is24Hours: true,
                verifiedAt: validStart,
                expiresAt: validStart.addingTimeInterval(100 * 24 * 60 * 60 + 1)
            ),
            makeAvailability(is24Hours: true, offersNightService: false),
            makeAvailability(is24Hours: true, displayLabel: "  "),
            makeAvailability(is24Hours: true, displayLabel: "\u{2060}"),
            makeAvailability(weeklyHours: ["thu": regularDay], is24Hours: true),
            makeAvailability(weeklyHours: ["sun": regularDay], omitWeekday: "sat"),
            makeAvailability(weeklyHours: ["holiday": regularDay]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "8:00", closesAt: "20:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "😀:", closesAt: "20:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "０8:00", closesAt: "20:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "0\u{2060}:00", closesAt: "20:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "24:00", closesAt: "20:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [ClinicHoursInterval(opensAt: "08:00", closesAt: "08:00")]
            ]),
            makeAvailability(weeklyHours: [
                "thu": [
                    ClinicHoursInterval(opensAt: "08:00", closesAt: "12:00"),
                    ClinicHoursInterval(opensAt: "11:00", closesAt: "14:00")
                ]
            ]),
            makeAvailability(weeklyHours: [
                "wed": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")],
                "thu": [ClinicHoursInterval(opensAt: "01:00", closesAt: "03:00")]
            ]),
            makeAvailability(weeklyHours: [
                "sun": [ClinicHoursInterval(opensAt: "01:00", closesAt: "03:00")],
                "sat": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
            ])
        ]

        for (index, availability) in invalidPayloads.enumerated() {
            assertInvalidAvailability(availability, at: now, message: "mutation \(index)")
        }
    }

    func testClinicAvailabilityFeedbackReasonMatrixRequiresCurrentData() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        XCTAssertEqual(
            ClinicAvailabilityFeedback.reasons(
                for: makeAvailability(weeklyHours: [:]),
                at: now
            ),
            [.differentHours, .closedOrSuspended, .otherAvailabilityIssue]
        )
        XCTAssertEqual(
            ClinicAvailabilityFeedback.reasons(
                for: makeAvailability(is24Hours: true),
                at: now
            ),
            [
                .differentHours,
                .closedOrSuspended,
                .otherAvailabilityIssue,
                .notOpen24Hours,
                .nightOrEmergencyChanged
            ]
        )
        XCTAssertEqual(
            ClinicAvailabilityFeedback.reasons(
                for: makeAvailability(offersNightService: true),
                at: now
            ),
            [
                .differentHours,
                .closedOrSuspended,
                .otherAvailabilityIssue,
                .nightOrEmergencyChanged
            ]
        )
        XCTAssertTrue(
            ClinicAvailabilityFeedback.reasons(
                for: makeAvailability(is24Hours: true),
                at: Date(timeIntervalSince1970: 1_777_766_400)
            ).isEmpty
        )
        XCTAssertTrue(ClinicAvailabilityFeedback.reasons(for: nil, at: now).isEmpty)
    }

    func testClinicAvailabilityFeedbackFormatsFixedSanitizedReport() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let availability = makeAvailability(
            is24Hours: true,
            sourceURL: URL(string: "https://example.com/private-hours")!,
            sourceName: "官方\n\u{0000}網站"
        )
        let report = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: availability,
            at: now
        )

        XCTAssertEqual(
            report,
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1"
                + "｜來源名稱：官方 網站｜核實日期：2026-01-01"
        )
        XCTAssertFalse(report?.contains("\n") == true)
        XCTAssertFalse(report?.contains("\u{0000}") == true)
        XCTAssertFalse(report?.contains(availability.sourceURL.absoluteString) == true)
        XCTAssertFalse(report?.contains("+852 2123 4567") == true)
        XCTAssertNil(
            ClinicAvailabilityFeedback.reportReason(
                .notOpen24Hours,
                availability: makeAvailability(),
                at: now
            )
        )
    }

    func testClinicAvailabilityFeedbackRedactsSensitiveSourceNamesAndCapsLength() {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        for sensitiveSource in [
            "https://example.com/hours",
            "clinic.example.com",
            "2123/4567",
            "(852) 2123.4567",
            "+852 2123 4567",
            "ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ",
            "診所。香港",
            "診所.香港",
            "例子.com",
            "官方∣來源",
            "官方│來源"
        ] {
            let report = ClinicAvailabilityFeedback.reportReason(
                .differentHours,
                availability: makeAvailability(
                    is24Hours: true,
                    sourceName: sensitiveSource
                ),
                at: now
            )
            XCTAssertTrue(report?.contains("來源名稱：官方來源") == true)
            XCTAssertFalse(report?.contains(sensitiveSource) == true)
        }

        let ordinaryChineseSentence = "香港診所。官方網站資料"
        let ordinaryReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: makeAvailability(
                is24Hours: true,
                sourceName: ordinaryChineseSentence
            ),
            at: now
        )
        XCTAssertTrue(ordinaryReport?.contains("來源名稱：\(ordinaryChineseSentence)") == true)
        guard case let .structured(ordinaryTicket) = ClinicAvailabilityFeedback.classify(
            ordinaryReport ?? ""
        ) else {
            return XCTFail("ordinary Chinese sentence must remain a safe source name")
        }
        XCTAssertEqual(ordinaryTicket.sourceName, ordinaryChineseSentence)

        let injectedReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: makeAvailability(
                is24Hours: true,
                sourceName: "官方｜來源|偽造"
            ),
            at: now
        )
        XCTAssertTrue(injectedReport?.contains("來源名稱：官方 來源 偽造") == true)
        XCTAssertFalse(injectedReport?.contains("來源名稱：官方｜來源|偽造") == true)

        let longReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: makeAvailability(
                is24Hours: true,
                sourceName: String(repeating: "官", count: 1_000)
            ),
            at: now
        )
        XCTAssertNotNil(longReport)
        XCTAssertLessThanOrEqual(longReport?.count ?? .max, 500)
    }

    func testClinicAvailabilityFeedbackStrictParserRoundTripsAllReasons() throws {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let availability = makeAvailability(
            is24Hours: true,
            sourceName: "官方網站"
        )

        for reason in ClinicAvailabilityFeedbackReason.allCases {
            let canonical = try XCTUnwrap(
                ClinicAvailabilityFeedback.reportReason(
                    reason,
                    availability: availability,
                    at: now
                )
            )
            let classification = ClinicAvailabilityFeedback.classify(canonical)
            guard case let .structured(ticket) = classification else {
                return XCTFail("canonical report must classify as structured")
            }
            XCTAssertEqual(ticket.reason, reason)
            XCTAssertEqual(ticket.migrationID, "hk-clinic-hours-test-v1")
            XCTAssertEqual(ticket.sourceName, "官方網站")
            XCTAssertEqual(ticket.verifiedDate, "2026-01-01")
            XCTAssertEqual(ticket.canonicalReportReason, canonical)
            XCTAssertTrue(classification.isAvailabilityFeedback)
            XCTAssertFalse(classification.allowsTakeDown)
        }
    }

    func testClinicAvailabilityFeedbackMalformedPrefixFailsClosed() {
        let malformedReasons = [
            "營業資料回報｜原因：營業時間不同",
            "營業資料回報｜migrationId：hk-clinic-hours-test-v1｜原因：營業時間不同｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：任意原因｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：unsafe｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：clinic.example.com｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：診所。香港｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：診所.香港｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：例子.com｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方∣來源｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方│來源｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方網站｜核實日期：2026-02-30",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方網站｜核實日期：2026-01-01｜額外：欄位",
            "營業資料回報|原因：營業時間不同|migrationId：hk-clinic-hours-test-v1|來源名稱：官方網站|核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：\(String(repeating: "官", count: 501))｜核實日期：2026-01-01"
        ]

        for malformedReason in malformedReasons {
            let classification = ClinicAvailabilityFeedback.classify(malformedReason)
            guard case let .malformed(rawReason) = classification else {
                return XCTFail("reserved availability prefix must fail closed")
            }
            XCTAssertEqual(rawReason, malformedReason)
            XCTAssertTrue(classification.isAvailabilityFeedback)
            XCTAssertFalse(classification.allowsTakeDown)
        }

        let canonical = "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-test-v1｜來源名稱：官方網站｜核實日期：2026-01-01"
        let dirtyReservedPrefixes = [
            " " + canonical,
            "\n" + canonical,
            "\u{00A0}" + canonical,
            "\u{FEFF}" + canonical,
            "\u{2060}" + canonical,
            canonical.replacingOccurrences(
                of: "｜",
                with: "∣",
                options: [],
                range: canonical.range(of: "｜")
            ),
            canonical.replacingOccurrences(
                of: "｜",
                with: "│",
                options: [],
                range: canonical.range(of: "｜")
            )
        ]
        for dirtyReason in dirtyReservedPrefixes {
            let clinicClassification = ClinicAvailabilityFeedback.classify(dirtyReason)
            guard case let .malformed(rawReason) = clinicClassification else {
                return XCTFail("dirty reserved prefix must fail closed")
            }
            XCTAssertEqual(rawReason, dirtyReason)
            XCTAssertFalse(clinicClassification.allowsTakeDown)

            let nonClinicClassification = ClinicAvailabilityFeedback.classify(
                dirtyReason,
                isClinicReport: false
            )
            XCTAssertEqual(nonClinicClassification, .general(dirtyReason))
            XCTAssertTrue(nonClinicClassification.allowsTakeDown)
        }

        for generalReason in ["資料不實", "營業資料回報", "營業資料回報唔準"] {
            let general = ClinicAvailabilityFeedback.classify(generalReason)
            XCTAssertEqual(general, .general(generalReason))
            XCTAssertFalse(general.isAvailabilityFeedback)
            XCTAssertTrue(general.allowsTakeDown)
        }

        let reviewWithReservedPrefix = ClinicAvailabilityFeedback.classify(
            canonical,
            isClinicReport: false
        )
        XCTAssertEqual(reviewWithReservedPrefix, .general(canonical))
        XCTAssertTrue(reviewWithReservedPrefix.allowsTakeDown)
    }

    func testClinicAvailabilityFeedbackVerificationTicketIsExactAndPrivate() throws {
        let now = Date(timeIntervalSince1970: 1_775_102_400)
        let availability = makeAvailability(
            is24Hours: true,
            sourceURL: URL(string: "https://example.com/private-hours")!,
            sourceName: "官方\n網站"
        )
        let canonical = try XCTUnwrap(
            ClinicAvailabilityFeedback.reportReason(
                .differentHours,
                availability: availability,
                at: now
            )
        )
        guard case let .structured(ticket) = ClinicAvailabilityFeedback.classify(canonical) else {
            return XCTFail("canonical report must classify as structured")
        }

        let exported = ticket.verificationTicket(
            clinicID: "clinic-001",
            clinicName: "香港獸醫診所"
        )
        XCTAssertEqual(
            exported,
            "VetMap 營業資料重新核實工單\n"
                + "診所 ID：clinic-001\n"
                + "診所名稱：香港獸醫診所\n"
                + "回報原因：營業時間不同\n"
                + "migrationId：hk-clinic-hours-test-v1\n"
                + "來源名稱：官方 網站\n"
                + "原核實日期：2026-01-01\n"
                + "處理要求：需重新核實，不可直接套用回報內容"
        )
        for privateValue in [
            "report-id-private",
            "reporter-uid-private",
            "+852 2123 4567",
            availability.sourceURL.absoluteString
        ] {
            XCTAssertFalse(exported.contains(privateValue))
        }
    }

    func testClosedClinicWithCurrentNightServiceKeepsNightServiceLabel() {
        let thursdayAfterClose = Date(timeIntervalSince1970: 1_775_134_800)
        let clinic = makeClinic(
            availability: makeAvailability(
                weeklyHours: [
                    "thu": [
                        ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")
                    ]
                ],
                offersNightService: true
            )
        )

        XCTAssertEqual(clinic.operatingStatus(at: thursdayAfterClose), .closed)
        XCTAssertFalse(clinic.isOpen(at: thursdayAfterClose))
        XCTAssertEqual(clinic.availabilityLabel(at: thursdayAfterClose), "設夜診")
    }

    func testClinicWithoutAvailabilityHasNoAvailabilityLabel() {
        let clinic = makeClinic(availability: nil)

        XCTAssertEqual(clinic.operatingStatus(at: date), .unavailable)
        XCTAssertFalse(clinic.isOpen(at: date))
        XCTAssertNil(clinic.availabilityLabel(at: date))
    }

    func testReconciledClinicSelectionReturnsNilWithoutVisibleClinics() {
        XCTAssertNil(reconciledClinicSelection(currentID: "clinic-1", visibleIDs: []))
    }

    func testReconciledClinicSelectionKeepsCurrentVisibleClinic() {
        XCTAssertEqual(
            reconciledClinicSelection(currentID: "clinic-2", visibleIDs: ["clinic-1", "clinic-2"]),
            "clinic-2"
        )
    }

    func testReconciledClinicSelectionUsesFirstVisibleClinicWithoutCurrentSelection() {
        XCTAssertEqual(
            reconciledClinicSelection(currentID: nil, visibleIDs: ["clinic-1", "clinic-2"]),
            "clinic-1"
        )
    }

    func testReconciledClinicSelectionUsesFirstVisibleClinicWhenCurrentIsInvalid() {
        XCTAssertEqual(
            reconciledClinicSelection(currentID: "removed-clinic", visibleIDs: ["clinic-1", "clinic-2"]),
            "clinic-1"
        )
    }

    func testPendingMapLocationCountReturnsDirectoryMinusMarkers() {
        XCTAssertEqual(pendingMapLocationCount(directoryCount: 179, markerCount: 161), 18)
    }

    func testPendingMapLocationCountReturnsZeroWhenAllClinicsAreMappable() {
        XCTAssertEqual(pendingMapLocationCount(directoryCount: 11, markerCount: 11), 0)
    }

    func testPendingMapLocationCountNeverReturnsNegative() {
        XCTAssertEqual(pendingMapLocationCount(directoryCount: 1, markerCount: 2), 0)
    }

    func testAvailabilityClockTransitionReconcilesExpiredSelectionWithoutCameraFocus() {
        let scheduled = makeClinic(
            id: "scheduled",
            availability: makeAvailability(
                weeklyHours: [
                    "thu": [
                        ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")
                    ]
                ]
            )
        )
        let alwaysOpen = makeClinic(
            id: "always-open",
            availability: makeAvailability(is24Hours: true)
        )
        var filter = ClinicSearchFilter()
        filter.availability = .openNow

        let beforeClose = Date(timeIntervalSince1970: 1_775_131_140)
        let afterClose = Date(timeIntervalSince1970: 1_775_131_200)
        let beforeCloseIDs = filter.results(from: [scheduled, alwaysOpen], at: beforeClose).map(\.id)
        let afterCloseIDs = filter.results(from: [scheduled, alwaysOpen], at: afterClose).map(\.id)

        XCTAssertEqual(reconciledClinicSelection(currentID: scheduled.id, visibleIDs: beforeCloseIDs), scheduled.id)
        XCTAssertEqual(reconciledClinicSelection(currentID: scheduled.id, visibleIDs: afterCloseIDs), alwaysOpen.id)
        XCTAssertNil(reconciledClinicSelection(currentID: alwaysOpen.id, visibleIDs: []))
    }

    func testHongKongFilterKeepsCuratedDirectoryEntryWithoutCoordinate() {
        var filter = ClinicSearchFilter()
        filter.region = .hongKong
        let directoryOnly = makeClinic(
            id: "directory-only-clinic",
            address: "香港九龍測試地址",
            coordinate: nil,
            catalogRegion: "HK"
        )

        XCTAssertEqual(filter.results(from: [directoryOnly]).map(\.id), [directoryOnly.id])
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
        let reviewsURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let clinic = makeClinic(id: "detail-clinic")
        let repository = MockCommunityRepository(
            localReviewsFileURL: reviewsURL,
            localQuotesFileURL: quotesURL
        )
        XCTAssertNoThrow(try repository.addReview(makeReview(id: "detail-review", clinicId: clinic.id)))
        XCTAssertNoThrow(try repository.addQuote(makeQuote(id: "detail-quote", clinicId: clinic.id)))

        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        XCTAssertFalse(viewModel.reviews.isEmpty)
        XCTAssertFalse(viewModel.quotes.isEmpty)
        XCTAssertEqual(viewModel.reviews.map(\.clinicId).uniqueValues, [clinic.id])
        XCTAssertEqual(viewModel.quotes.map(\.clinicId).uniqueValues, [clinic.id])
    }

    @MainActor
    func testClinicDetailViewModelRequiresAuthenticationForValidReview() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        let result = await viewModel.submitReviewForModeration(
            ReviewDraft(
                rating: 5,
                title: "  新增成功  ",
                content: "  醫生解釋清楚，費用亦透明。  ",
                treatmentType: "洗牙",
                cost: Decimal(3_000)
            )
        )

        XCTAssertEqual(result, .authenticationRequired)
        XCTAssertEqual(viewModel.storageError, "請先登入後再提交評價。")
        XCTAssertFalse(viewModel.reviews.contains { $0.title == "新增成功" })
        XCTAssertTrue(repository.fetchLocalReviews().isEmpty)
    }

    @MainActor
    func testClinicDetailViewModelRejectsInvalidReviewDraft() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)
        let initialReviewCount = viewModel.reviews.count

        let result = await viewModel.submitReviewForModeration(
            ReviewDraft(
                rating: 0,
                title: " ",
                content: "內容",
                treatmentType: "",
                cost: nil
            )
        )

        XCTAssertEqual(result, .failed(message: "請填寫評分、標題和內容。"))
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
        viewModel.selectedRegion = .hongKong

        await viewModel.lookupAddressLocation()

        XCTAssertEqual(viewModel.selectedRegion, .custom)
        XCTAssertEqual(viewModel.latitude, "22.281123")
        XCTAssertEqual(viewModel.longitude, "114.158988")
        XCTAssertEqual(viewModel.locationLookupState, .resolved("已找到：中環動物醫院"))

        let clinic = try XCTUnwrap(viewModel.makeClinic())
        let coordinate = try XCTUnwrap(clinic.coordinate)
        XCTAssertEqual(coordinate.latitude, 22.281123, accuracy: 0.000001)
        XCTAssertEqual(coordinate.longitude, 114.158988, accuracy: 0.000001)
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
        XCTAssertFalse(viewModel.canSubmit)
    }

    @MainActor
    func testAddClinicViewModelRejectsGeocodedLocationOutsideHongKong() async {
        let viewModel = makeValidAddClinicViewModel(
            geocodingService: StubGeocodingService(
                result: .success(
                    GeocodingResult(
                        coordinate: ClinicCoordinate(latitude: 25.0381, longitude: 121.5432),
                        displayName: "海外診所"
                    )
                )
            )
        )
        viewModel.selectedRegion = .hongKong

        await viewModel.lookupAddressLocation()

        XCTAssertEqual(viewModel.selectedRegion, .hongKong)
        XCTAssertEqual(viewModel.locationLookupState, .failed("只接受香港境內的診所位置。"))
        XCTAssertFalse(viewModel.canSubmit)
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
        let clinicId = "load-reviews-clinic"
        XCTAssertNoThrow(try repository.addReview(makeReview(id: "load-1", clinicId: clinicId)))
        XCTAssertNoThrow(try repository.addReview(makeReview(id: "other-clinic", clinicId: "another-clinic")))

        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)

        XCTAssertGreaterThan(viewModel.reviews.count, 0)
        XCTAssertTrue(viewModel.reviews.allSatisfy { $0.clinicId == clinicId })
    }

    @MainActor
    func testReviewViewModelSortsByNewest() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let clinicId = "sort-newest-clinic"
        var older = makeReview(id: "older", clinicId: clinicId)
        older.createdAt = date.addingTimeInterval(-86_400)
        XCTAssertNoThrow(try repository.addReview(older))
        var newer = makeReview(id: "newer", clinicId: clinicId)
        newer.createdAt = date
        XCTAssertNoThrow(try repository.addReview(newer))
        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)

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
        XCTAssertNoThrow(try repository.addReview(low))

        var high = makeReview(id: "high", clinicId: clinicId, title: "High")
        high.rating = 5
        XCTAssertNoThrow(try repository.addReview(high))

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
        XCTAssertNoThrow(try repository.addReview(less))

        var more = makeReview(id: "more", clinicId: clinicId, title: "More")
        more.helpfulCount = 10
        XCTAssertNoThrow(try repository.addReview(more))

        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)
        viewModel.sortOrder = .mostHelpful
        let sorted = viewModel.sortedReviews

        XCTAssertEqual(sorted.count, 2)
        XCTAssertEqual(sorted[0].id, "more")
        XCTAssertEqual(sorted[1].id, "less")
    }

    @MainActor
    func testReviewViewModelMarkHelpfulWithoutLoadedReviewDoesNotFabricateReview() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(
            clinicId: "test-mark-helpful",
            repository: repository
        )
        XCTAssertTrue(viewModel.reviews.isEmpty)

        await viewModel.markHelpful("review-helpful")

        XCTAssertTrue(viewModel.reviews.isEmpty)
    }

    // MARK: - QuoteViewModel Tests

    @MainActor
    func testQuoteViewModelLoadsQuotesForClinic() {
        let quotesURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "quotes.json")
        let repository = MockCommunityRepository(localQuotesFileURL: quotesURL)
        let clinicId = "test-clinic-quotes"
        let quote = makeQuote(id: "quote-load-test", clinicId: clinicId)
        XCTAssertNoThrow(try repository.addQuote(quote))

        let viewModel = QuoteViewModel(clinicId: clinicId, repository: repository)

        XCTAssertGreaterThan(viewModel.quotes.count, 0)
        XCTAssertTrue(viewModel.quotes.allSatisfy { $0.clinicId == clinicId })
    }

    @MainActor
    func testQuoteViewModelRequiresAuthenticationForValidQuote() async {
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

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "洗牙",
                estimatedCost: Decimal(3000),
                actualCost: nil,
                currency: "TWD",
                notes: "測試報價"
            )
        )

        XCTAssertEqual(result, .authenticationRequired)
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請先登入後再提交報價。")
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
    func testProductViewModelHasNoBundledProductionCatalog() {
        let viewModel = ProductViewModel()

        XCTAssertTrue(viewModel.products.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testProductViewModelFiltersByCategory() {
        let viewModel = ProductViewModel()
        var matching = makeProduct()
        matching.category = "用品"
        var other = makeProduct()
        other.name = "寵物美容服務"
        other.category = "美容"
        viewModel.products = [matching, other]
        viewModel.selectedCategory = "用品"

        let filtered = viewModel.filteredProducts
        XCTAssertEqual(filtered.count, 1)
        XCTAssertTrue(filtered.allSatisfy { $0.category == "用品" })
    }

    // MARK: - InsuranceViewModel Tests

    @MainActor
    func testInsuranceViewModelHasNoBundledProductionCatalog() {
        let viewModel = InsuranceViewModel()

        XCTAssertTrue(viewModel.plans.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testInsuranceViewModelSortsByPremiumLowToHigh() {
        let viewModel = InsuranceViewModel()
        let officialQuote = makeInsurance(id: "insurance-official-quote", monthlyPremium: 0)
        let publishedPremium = makeInsurance(
            id: "insurance-published-premium",
            monthlyPremium: 500
        )
        viewModel.plans = [publishedPremium, officialQuote]
        viewModel.sortOrder = .lowToHigh
        let sorted = viewModel.sortedPlans

        XCTAssertEqual(sorted.map(\.monthlyPremium), [0, 500])
    }

    @MainActor
    func testInsuranceViewModelSortsByPremiumHighToLow() {
        let viewModel = InsuranceViewModel()
        let officialQuote = makeInsurance(id: "insurance-official-quote", monthlyPremium: 0)
        let publishedPremium = makeInsurance(
            id: "insurance-published-premium",
            monthlyPremium: 500
        )
        viewModel.plans = [officialQuote, publishedPremium]
        viewModel.sortOrder = .highToLow
        let sorted = viewModel.sortedPlans

        XCTAssertEqual(sorted.map(\.monthlyPremium), [500, 0])
    }

    @MainActor
    func testInsuranceViewModelShowsOfficialQuoteForZeroPremium() {
        let viewModel = InsuranceViewModel()

        XCTAssertEqual(viewModel.formattedPremium(0), "官方報價")
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

        XCTAssertTrue(results.allSatisfy { $0.priceLevel == 1 })
    }

    func testClinicSearchFilterPriceModerate() {
        var filter = ClinicSearchFilter()
        filter.price = .moderate

        let budget = makeClinic(id: "budget", priceLevel: 1)
        let moderate = makeClinic(id: "moderate", priceLevel: 2)
        let premium = makeClinic(id: "premium", priceLevel: 3)
        let unknown = makeClinic(id: "unknown", priceLevel: 0)

        let results = filter.results(from: [premium, moderate, budget, unknown])

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.allSatisfy { $0.priceLevel <= 2 })
        XCTAssertEqual(results.map(\.id).sorted(), ["budget", "moderate"])
    }

    // MARK: - ReviewDraft Validation Tests

    @MainActor
    func testReviewDraftRequiresRatingInRange() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let clinic = MockClinicRepository.hkClinics[0]
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ClinicDetailViewModel(clinic: clinic, repository: repository)

        let firstResult = await viewModel.submitReviewForModeration(
            ReviewDraft(rating: 1, title: "標題", content: "內容", treatmentType: "", cost: nil)
        )
        XCTAssertEqual(firstResult, .authenticationRequired)

        let secondResult = await viewModel.submitReviewForModeration(
            ReviewDraft(rating: 5, title: "標題2", content: "內容2", treatmentType: "", cost: nil)
        )
        XCTAssertEqual(secondResult, .authenticationRequired)

        let countBeforeInvalid = viewModel.reviews.count
        let invalidResult = await viewModel.submitReviewForModeration(
            ReviewDraft(rating: 6, title: "標題", content: "內容", treatmentType: "", cost: nil)
        )
        XCTAssertEqual(invalidResult, .failed(message: "請填寫評分、標題和內容。"))
        XCTAssertEqual(viewModel.reviews.count, countBeforeInvalid)
        XCTAssertEqual(viewModel.storageError, "請填寫評分、標題和內容。")
    }

    @MainActor
    func testReviewDraftTrimsWhitespace() {
        let viewModel = makeValidAddClinicViewModel()
        viewModel.name = "  測試診所  "
        viewModel.address = "  測試地址  "
        viewModel.phone = "  +852 2123 4567  "

        let clinic = viewModel.makeClinic()

        XCTAssertEqual(clinic?.name, "測試診所")
        XCTAssertEqual(clinic?.address, "測試地址")
        XCTAssertEqual(clinic?.phone, "+852 2123 4567")
    }

    // MARK: - AuthViewModel Tests (Local-Only Mode)

    @MainActor
    func testAuthViewModelInitialStateInLocalMode() async throws {
        let viewModel = AuthViewModel()
        // Firebase auth state listener fires async; wait for it to settle
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotEqual(viewModel.authState, .signedIn)
        XCTAssertNil(viewModel.user)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testAuthViewModelSignUpReturnsErrorMessageInLocalMode() async {
        let viewModel = AuthViewModel()

        await viewModel.signUp(email: "test@example.com", password: "password123", displayName: "Test User")

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        // With Firebase configured, signUp fails with a Firebase-specific error (not a local-mode message)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testAuthViewModelSignInReturnsErrorMessageInLocalMode() async {
        let viewModel = AuthViewModel()

        await viewModel.signIn(email: "test@example.com", password: "password123")

        XCTAssertEqual(viewModel.authState, .signedOut)
        XCTAssertNil(viewModel.user)
        // With Firebase configured, signIn fails with a Firebase-specific error (not a local-mode message)
        XCTAssertNotNil(viewModel.errorMessage)
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

        // errorMessage is cleared to nil at start of signIn, then set to Firebase error on failure
        XCTAssertNotEqual(viewModel.errorMessage, "Old error")
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
    func testReviewViewModelMarkHelpfulOnNonExistentReviewIsNoop() async {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let viewModel = ReviewViewModel(clinicId: "taipei-anxin", repository: repository)
        let initialReviews = viewModel.reviews

        await viewModel.markHelpful("nonexistent-review-id")

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
        let clinicId = "test-quote-sort"

        let newerQuote = makeQuote(id: "quote-sort-newer", clinicId: clinicId,
                                   createdAt: Date(timeIntervalSince1970: 1_749_000_000))
        let olderQuote = makeQuote(id: "quote-sort-older", clinicId: clinicId,
                                   createdAt: Date(timeIntervalSince1970: 1_748_000_000))
        XCTAssertNoThrow(try repository.addQuote(olderQuote))
        XCTAssertNoThrow(try repository.addQuote(newerQuote))

        let viewModel = QuoteViewModel(clinicId: clinicId, repository: repository)
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
    func testQuoteViewModelRejectsEmptyTreatmentType() async {
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

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "   ",
                estimatedCost: Decimal(1000),
                actualCost: nil,
                currency: "TWD",
                notes: "test"
            )
        )

        XCTAssertEqual(result, .failed(message: "請填寫治療類型和預估費用。"))
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelRejectsZeroEstimatedCost() async {
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

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "洗牙",
                estimatedCost: Decimal(0),
                actualCost: nil,
                currency: "TWD",
                notes: "test"
            )
        )

        XCTAssertEqual(result, .failed(message: "請填寫治療類型和預估費用。"))
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelRejectsNegativeEstimatedCost() async {
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

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "洗牙",
                estimatedCost: Decimal(-1),
                actualCost: nil,
                currency: "TWD",
                notes: "test"
            )
        )

        XCTAssertEqual(result, .failed(message: "請填寫治療類型和預估費用。"))
        XCTAssertEqual(viewModel.quotes.count, initialCount)
        XCTAssertEqual(viewModel.storageError, "請填寫治療類型和預估費用。")
    }

    @MainActor
    func testQuoteViewModelWhitespaceTreatmentDraftRequiresAuthentication() async {
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
        let initialQuotes = viewModel.quotes

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "  一般診療  ",
                estimatedCost: Decimal(500),
                actualCost: nil,
                currency: "TWD",
                notes: "test"
            )
        )

        XCTAssertEqual(result, .authenticationRequired)
        XCTAssertEqual(viewModel.storageError, "請先登入後再提交報價。")
        XCTAssertEqual(viewModel.quotes, initialQuotes)
    }

    @MainActor
    func testQuoteViewModelWhitespaceNotesDraftRequiresAuthentication() async {
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
        let initialQuotes = viewModel.quotes

        let result = await viewModel.addQuote(
            QuoteDraft(
                treatmentType: "健檢",
                estimatedCost: Decimal(1500),
                actualCost: nil,
                currency: "TWD",
                notes: "  含血檢  "
            )
        )

        XCTAssertEqual(result, .authenticationRequired)
        XCTAssertEqual(viewModel.storageError, "請先登入後再提交報價。")
        XCTAssertEqual(viewModel.quotes, initialQuotes)
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
        var supplies = makeProduct()
        supplies.category = "用品"
        var grooming = makeProduct()
        grooming.name = "寵物美容服務"
        grooming.category = "美容"
        viewModel.products = [supplies, grooming]
        viewModel.selectedCategory = "美容"

        XCTAssertEqual(viewModel.filteredProducts.map(\.category), ["美容"])

        viewModel.selectedCategory = "全部"

        XCTAssertEqual(viewModel.filteredProducts.count, 2)
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

        XCTAssertEqual(categories.count, 8)
        XCTAssertTrue(categories.contains("全部"))
        XCTAssertTrue(categories.contains("用品"))
        XCTAssertTrue(categories.contains("美容"))
        XCTAssertTrue(categories.contains("善終"))
        XCTAssertTrue(categories.contains("食品"))
        XCTAssertTrue(categories.contains("藥品"))
    }

    @MainActor
    func testProductViewModelEachProductHasValidCategory() {
        let viewModel = ProductViewModel()
        var supplies = makeProduct()
        supplies.category = "用品"
        var grooming = makeProduct()
        grooming.category = "美容"
        viewModel.products = [supplies, grooming]

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
        viewModel.products = [makeProduct()]
        viewModel.selectedCategory = "食品"

        let filtered = viewModel.filteredProducts

        XCTAssertTrue(filtered.isEmpty)
    }

    @MainActor
    func testProductViewModelFilteredByMedicineCategory() {
        let viewModel = ProductViewModel()
        viewModel.products = [makeProduct()]
        viewModel.selectedCategory = "藥品"

        let filtered = viewModel.filteredProducts

        XCTAssertTrue(filtered.isEmpty)
    }

    // MARK: - InsuranceViewModel Additional Tests

    @MainActor
    func testInsuranceViewModelUsesHongKongCurrency() {
        let viewModel = InsuranceViewModel()
        let plan = makeInsurance()

        XCTAssertEqual(viewModel.currency(for: plan), "HKD")
    }

    @MainActor
    func testInsuranceViewModelPlansWithSimilarPremiumExcludesSelf() {
        let viewModel = InsuranceViewModel()
        let firstPlan = makeInsurance(id: "insurance-1", monthlyPremium: 0)
        let secondPlan = makeInsurance(id: "insurance-2", monthlyPremium: 300)
        viewModel.plans = [firstPlan, secondPlan]

        let similar = viewModel.plansWithSimilarPremium(to: firstPlan, count: 3)

        XCTAssertFalse(similar.contains(where: { $0.id == firstPlan.id }))
    }

    @MainActor
    func testInsuranceViewModelPlansWithSimilarPremiumRespectsCount() {
        let viewModel = InsuranceViewModel()
        let firstPlan = makeInsurance(id: "insurance-1", monthlyPremium: 0)
        viewModel.plans = [
            firstPlan,
            makeInsurance(id: "insurance-2", monthlyPremium: 100),
            makeInsurance(id: "insurance-3", monthlyPremium: 200),
            makeInsurance(id: "insurance-4", monthlyPremium: 300)
        ]

        let similar = viewModel.plansWithSimilarPremium(to: firstPlan, count: 2)

        XCTAssertEqual(similar.count, 2)
    }

    @MainActor
    func testInsuranceViewModelSortedPlansAreInCorrectPremiumOrder() {
        let viewModel = InsuranceViewModel()
        viewModel.plans = [
            makeInsurance(id: "insurance-1", monthlyPremium: 300),
            makeInsurance(id: "insurance-2", monthlyPremium: 0),
            makeInsurance(id: "insurance-3", monthlyPremium: 200)
        ]

        viewModel.sortOrder = .lowToHigh
        let lowToHigh = viewModel.sortedPlans
        XCTAssertEqual(lowToHigh.map(\.monthlyPremium), [0, 200, 300])

        viewModel.sortOrder = .highToLow
        let highToLow = viewModel.sortedPlans
        XCTAssertEqual(highToLow.map(\.monthlyPremium), [300, 200, 0])
    }

    @MainActor
    func testInsuranceOfficialDirectoryPlanAllowsQuoteOnlyFields() {
        let plan = makeInsurance()

        XCTAssertFalse(plan.id.isEmpty)
        XCTAssertFalse(plan.providerName.isEmpty)
        XCTAssertFalse(plan.planName.isEmpty)
        XCTAssertEqual(plan.monthlyPremium, 0)
        XCTAssertTrue(plan.coverage.isEmpty)
        XCTAssertTrue(plan.exclusions.isEmpty)
        XCTAssertTrue(plan.contactPhone.isEmpty)
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
        name: String = "安心動物醫院",
        address: String = "香港旺角彌敦道1號",
        coordinate: ClinicCoordinate? = ClinicCoordinate(
            latitude: 22.3193,
            longitude: 114.1694
        ),
        catalogRegion: String? = nil,
        services: [String] = ["一般診療", "牙科"],
        tags: [String] = ["貓友善", "急診"],
        priceLevel: Int = 2,
        verified: Bool = true,
        availability: ClinicAvailability? = nil
    ) -> VetClinic {
        VetClinic(
            id: id,
            name: name,
            address: address,
            coordinate: coordinate,
            catalogRegion: catalogRegion,
            phone: "+852 2123 4567",
            website: URL(string: "https://example.com/clinic"),
            openingHours: ["Mon": "09:00-18:00"],
            availability: availability,
            services: services,
            avgRating: 4.7,
            reviewCount: 128,
            priceLevel: priceLevel,
            images: [URL(string: "https://example.com/clinic.jpg")!],
            tags: tags,
            createdAt: date,
            updatedAt: date,
            reportedBy: "user-1",
            verified: verified
        )
    }

    private func makeAvailability(
        weeklyHours: [String: [ClinicHoursInterval]] = [:],
        schemaVersion: Int = 1,
        migrationId: String = "hk-clinic-hours-test-v1",
        timeZoneIdentifier: String = "Asia/Hong_Kong",
        is24Hours: Bool = false,
        offersNightService: Bool? = nil,
        displayLabel: String? = nil,
        serviceNote: String = "測試營業資料",
        sourceURL: URL = URL(string: "https://example.com/hours")!,
        sourceName: String = "測試官方網站",
        verifiedAt: Date = Date(timeIntervalSince1970: 1_767_225_600),
        expiresAt: Date = Date(timeIntervalSince1970: 1_775_577_600),
        omitWeekday: String? = nil
    ) -> ClinicAvailability {
        let weekdayKeys = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        var normalizedWeeklyHours: [String: [ClinicHoursInterval]] = is24Hours
            ? [:]
            : Dictionary(uniqueKeysWithValues: weekdayKeys.map { ($0, []) })
        for (weekday, intervals) in weeklyHours {
            normalizedWeeklyHours[weekday] = intervals
        }
        if let omitWeekday {
            normalizedWeeklyHours.removeValue(forKey: omitWeekday)
        }
        return ClinicAvailability(
            schemaVersion: schemaVersion,
            migrationId: migrationId,
            timeZoneIdentifier: timeZoneIdentifier,
            weeklyHours: normalizedWeeklyHours,
            is24Hours: is24Hours,
            offersNightService: offersNightService ?? is24Hours,
            displayLabel: displayLabel ?? (is24Hours ? "24 小時" : ""),
            serviceNote: serviceNote,
            sourceURL: sourceURL,
            sourceName: sourceName,
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
    }

    private func assertInvalidAvailability(
        _ availability: ClinicAvailability,
        at date: Date,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let clinic = makeClinic(availability: availability)
        XCTAssertFalse(availability.isCurrent(at: date), message, file: file, line: line)
        XCTAssertFalse(clinic.hasCurrentAvailability(at: date), message, file: file, line: line)
        XCTAssertFalse(clinic.hasCurrentNightService(at: date), message, file: file, line: line)
        XCTAssertEqual(clinic.operatingStatus(at: date), .unavailable, message, file: file, line: line)
        XCTAssertFalse(clinic.isOpen(at: date), message, file: file, line: line)
        XCTAssertNil(clinic.availabilityLabel(at: date), message, file: file, line: line)

        var filter = ClinicSearchFilter()
        for availabilityFilter in [
            ClinicSearchFilter.Availability.openNow,
            .open24Hours,
            .nightService
        ] {
            filter.availability = availabilityFilter
            XCTAssertTrue(
                filter.results(from: [clinic], at: date).isEmpty,
                message,
                file: file,
                line: line
            )
        }
        filter.availability = .all
        XCTAssertEqual(
            filter.results(from: [clinic], at: date).map(\.id),
            [clinic.id],
            message,
            file: file,
            line: line
        )
    }

    @MainActor
    private func makeValidAddClinicViewModel(
        geocodingService: GeocodingServicing = GeocodingService()
    ) -> AddClinicViewModel {
        let viewModel = AddClinicViewModel(geocodingService: geocodingService)
        viewModel.name = "座標測試診所"
        viewModel.address = "香港測試地址"
        viewModel.phone = "+852 2123 4567"
        viewModel.selectedRegion = .custom
        viewModel.latitude = "22.3193"
        viewModel.longitude = "114.1694"
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
            name: "香港寵物用品服務",
            description: "香港寵物用品服務目錄。",
            category: "用品",
            price: 0,
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: [],
            createdAt: date
        )
    }

    private func makeQuote(
        id: String = "quote-1",
        clinicId: String = "clinic-1",
        createdAt: Date? = nil
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
            createdAt: createdAt ?? date
        )
    }

    private func makeInsurance(
        id: String = "insurance-1",
        monthlyPremium: Decimal = 0
    ) -> Insurance {
        Insurance(
            id: id,
            providerName: "香港寵物保險供應商",
            planName: "官方方案目錄",
            description: "詳情以供應商官方資料及報價為準。",
            monthlyPremium: monthlyPremium,
            annualPremium: 0,
            coverage: [],
            exclusions: [],
            website: URL(string: "https://www.example.com.hk/pet-insurance")!,
            contactPhone: ""
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
