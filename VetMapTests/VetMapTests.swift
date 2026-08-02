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
    func testReviewViewModelMarksHelpful() {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "reviews.json")
        let repository = MockCommunityRepository(localReviewsFileURL: fileURL)
        let clinicId = "test-mark-helpful"
        let review = makeReview(id: "review-helpful", clinicId: clinicId)
        XCTAssertNoThrow(try repository.addReview(review))

        let viewModel = ReviewViewModel(clinicId: clinicId, repository: repository)

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
        let clinicId = "test-clinic-quotes"
        let quote = makeQuote(id: "quote-load-test", clinicId: clinicId)
        XCTAssertNoThrow(try repository.addQuote(quote))

        let viewModel = QuoteViewModel(clinicId: clinicId, repository: repository)

        XCTAssertGreaterThan(viewModel.quotes.count, 0)
        XCTAssertTrue(viewModel.quotes.allSatisfy { $0.clinicId == clinicId })
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
