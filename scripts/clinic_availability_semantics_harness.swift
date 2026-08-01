import Foundation

@main
struct ClinicAvailabilitySemanticsHarness {
    private static let now = Date(timeIntervalSince1970: 1_775_102_400)
    private static let verifiedAt = Date(timeIntervalSince1970: 1_775_000_000)
    private static let expiresAt = verifiedAt.addingTimeInterval(90 * 24 * 60 * 60)
    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    static func main() {
        let positive = [
            availability(is24Hours: true),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [
                    ClinicHoursInterval(opensAt: "09:00", closesAt: "13:00"),
                    ClinicHoursInterval(opensAt: "14:00", closesAt: "19:00")
                ]
            ]),
            availability(hours: [
                "wed": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
            ], offersNightService: true),
            availability(hours: [
                "sat": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
            ], offersNightService: true)
        ]
        for payload in positive {
            precondition(payload.isCurrent(at: now), "canonical payload rejected")
        }
        let alwaysOpenClinic = clinic(with: positive[0])
        for availabilityFilter in [
            ClinicSearchFilter.Availability.openNow,
            .open24Hours,
            .nightService,
            .all
        ] {
            var filter = ClinicSearchFilter()
            filter.availability = availabilityFilter
            precondition(filter.results(from: [alwaysOpenClinic], at: now).count == 1)
        }
        var scheduledOpenFilter = ClinicSearchFilter()
        scheduledOpenFilter.availability = .openNow
        precondition(
            scheduledOpenFilter.results(from: [clinic(with: positive[1])], at: now).count == 1
        )

        let day = [ClinicHoursInterval(opensAt: "08:00", closesAt: "20:00")]
        let invalid = [
            availability(schemaVersion: 2, is24Hours: true),
            availability(migrationId: "", is24Hours: true),
            availability(migrationId: "other-v1", is24Hours: true),
            availability(migrationId: "hk-clinic-hours-v1\u{2060}", is24Hours: true),
            availability(migrationId: "hk-clinic-hours-v1\u{FEFF}", is24Hours: true),
            availability(timeZone: "Asia/Taipei", is24Hours: true),
            availability(is24Hours: true, sourceURL: URL(string: "http://example.com")!),
            availability(is24Hours: true, sourceURL: URL(string: "https:///hours")!),
            availability(is24Hours: true, sourceName: "  "),
            availability(is24Hours: true, sourceName: "\u{2060}"),
            availability(is24Hours: true, serviceNote: "\n"),
            availability(is24Hours: true, serviceNote: "\u{FEFF}"),
            availability(
                is24Hours: true,
                verifiedAt: expiresAt,
                expiresAt: verifiedAt
            ),
            availability(
                is24Hours: true,
                verifiedAt: now.addingTimeInterval(1)
            ),
            availability(is24Hours: true, expiresAt: now),
            availability(
                is24Hours: true,
                expiresAt: verifiedAt.addingTimeInterval(100 * 24 * 60 * 60 + 1)
            ),
            availability(is24Hours: true, offersNightService: false),
            availability(is24Hours: true, displayLabel: " "),
            availability(is24Hours: true, displayLabel: "\u{2060}"),
            availability(hours: ["thu": day], is24Hours: true),
            availability(hours: ["sun": day], omittedWeekday: "sat"),
            availability(hours: ["holiday": day]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "8:00", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "😀:", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "０8:00", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "0\u{2060}:00", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "24:00", closesAt: "20:00")]
            ]),
            availability(hours: [
                "thu": [ClinicHoursInterval(opensAt: "08:00", closesAt: "08:00")]
            ]),
            availability(hours: [
                "thu": [
                    ClinicHoursInterval(opensAt: "08:00", closesAt: "12:00"),
                    ClinicHoursInterval(opensAt: "11:00", closesAt: "14:00")
                ]
            ]),
            availability(hours: [
                "wed": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")],
                "thu": [ClinicHoursInterval(opensAt: "01:00", closesAt: "03:00")]
            ]),
            availability(hours: [
                "sun": [ClinicHoursInterval(opensAt: "01:00", closesAt: "03:00")],
                "sat": [ClinicHoursInterval(opensAt: "21:00", closesAt: "02:00")]
            ])
        ]
        for payload in invalid {
            assertFailClosed(payload)
        }

        let expiryBoundary = availability(
            is24Hours: true,
            verifiedAt: verifiedAt,
            expiresAt: verifiedAt.addingTimeInterval(24 * 60 * 60)
        )
        precondition(expiryBoundary.isCurrent(at: verifiedAt))
        precondition(!expiryBoundary.isCurrent(at: expiryBoundary.expiresAt))
        let exactlyOneHundredDays = availability(
            is24Hours: true,
            verifiedAt: verifiedAt,
            expiresAt: verifiedAt.addingTimeInterval(100 * 24 * 60 * 60)
        )
        precondition(exactlyOneHundredDays.isCurrent(at: verifiedAt))

        print("{\"count\":\(positive.count + invalid.count + 3),\"passed\":true}")
    }

    private static func availability(
        hours: [String: [ClinicHoursInterval]] = [:],
        schemaVersion: Int = 1,
        migrationId: String = "hk-clinic-hours-harness-v1",
        timeZone: String = "Asia/Hong_Kong",
        is24Hours: Bool = false,
        offersNightService: Bool? = nil,
        displayLabel: String? = nil,
        serviceNote: String = "官方營業資料",
        sourceURL: URL = URL(string: "https://example.com/hours")!,
        sourceName: String = "官方網站",
        verifiedAt: Date = verifiedAt,
        expiresAt: Date = expiresAt,
        omittedWeekday: String? = nil
    ) -> ClinicAvailability {
        var normalized: [String: [ClinicHoursInterval]] = is24Hours
            ? [:]
            : Dictionary(uniqueKeysWithValues: weekdays.map { ($0, []) })
        for (weekday, intervals) in hours {
            normalized[weekday] = intervals
        }
        if let omittedWeekday {
            normalized.removeValue(forKey: omittedWeekday)
        }
        return ClinicAvailability(
            schemaVersion: schemaVersion,
            migrationId: migrationId,
            timeZoneIdentifier: timeZone,
            weeklyHours: normalized,
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

    private static func assertFailClosed(_ payload: ClinicAvailability) {
        let clinic = clinic(with: payload)
        precondition(!payload.isCurrent(at: now), "invalid payload is current")
        precondition(!clinic.hasCurrentAvailability(at: now))
        precondition(!clinic.hasCurrentNightService(at: now))
        precondition(clinic.operatingStatus(at: now) == .unavailable)
        precondition(!clinic.isOpen(at: now))
        precondition(clinic.availabilityLabel(at: now) == nil)
        for availabilityFilter in [
            ClinicSearchFilter.Availability.openNow,
            .open24Hours,
            .nightService
        ] {
            var filter = ClinicSearchFilter()
            filter.availability = availabilityFilter
            precondition(filter.results(from: [clinic], at: now).isEmpty)
        }
        var allFilter = ClinicSearchFilter()
        allFilter.availability = .all
        precondition(allFilter.results(from: [clinic], at: now).count == 1)
    }

    private static func clinic(with payload: ClinicAvailability) -> VetClinic {
        VetClinic(
            id: "harness-clinic",
            name: "Harness Clinic",
            address: "Hong Kong",
            coordinate: ClinicCoordinate(latitude: 22.3, longitude: 114.2),
            catalogRegion: "HK",
            phone: "12345678",
            website: nil,
            openingHours: [:],
            availability: payload,
            services: [],
            avgRating: 0,
            reviewCount: 0,
            priceLevel: 0,
            images: [],
            tags: [],
            createdAt: now,
            updatedAt: now,
            reportedBy: "harness",
            verified: false
        )
    }
}
