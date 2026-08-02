import Foundation

private struct HoursManifest: Codable {
    let schemaVersion: Int
    let migrationId: String?
    let catalogRegion: String
    let timeZoneIdentifier: String
    let verifiedAt: Date
    let expiresAt: Date
    let count: Int
    let clinics: [HoursClinic]
}

private struct HoursClinic: Codable {
    let clinicID: String
    let expectedName: String
    let is24Hours: Bool
    let offersNightService: Bool
    let displayLabel: String
    let serviceNote: String
    let weeklyHours: [String: [ClinicHoursInterval]]
    let sourceName: String
    let sourceURL: URL
}

@main
struct ClinicAvailabilityManifestCompatibilityHarness {
    private static let v1MigrationID = "hk-clinic-hours-v1-2026-07-30"
    private static let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw HarnessError.usage
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let v1 = try decoder.decode(
            HoursManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        )
        let v2 = try decoder.decode(
            HoursManifest.self,
            from: Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        )

        try require(v1.schemaVersion == 1 && v2.schemaVersion == 1, "schema")
        try require(v1.catalogRegion == "HK" && v2.catalogRegion == "HK", "region")
        try require(
            v1.timeZoneIdentifier == "Asia/Hong_Kong"
                && v2.timeZoneIdentifier == "Asia/Hong_Kong",
            "timezone"
        )
        try require(v1.count == 11 && v1.clinics.count == 11, "v1 count")
        try require(v2.count == 4 && v2.clinics.count == 4, "v2 count")
        try require(v2.migrationId == "hk-clinic-hours-v2-2026-08-02", "v2 migration")
        try require(distribution(v1.clinics) == (11, 10, 1), "v1 distribution")
        try require(distribution(v2.clinics) == (4, 1, 3), "v2 distribution")

        let v1IDs = v1.clinics.map(\.clinicID)
        let v2IDs = v2.clinics.map(\.clinicID)
        try require(Set(v1IDs).count == 11, "duplicate v1 IDs")
        try require(Set(v2IDs).count == 4, "duplicate v2 IDs")
        try require(Set(v1IDs).isDisjoint(with: Set(v2IDs)), "overlapping IDs")

        let commonReference = max(v1.verifiedAt, v2.verifiedAt)
        try require(
            commonReference < v1.expiresAt && commonReference < v2.expiresAt,
            "no common manifest reference"
        )

        var scheduledIntervalProbes = 0
        var gapProbes = 0
        let projectedV1 = try project(
            v1,
            migrationID: v1MigrationID,
            commonReference: commonReference,
            scheduledIntervalProbes: &scheduledIntervalProbes,
            gapProbes: &gapProbes
        )
        let projectedV2 = try project(
            v2,
            migrationID: v2.migrationId!,
            commonReference: commonReference,
            scheduledIntervalProbes: &scheduledIntervalProbes,
            gapProbes: &gapProbes
        )
        let merged = projectedV1 + projectedV2
        try require(merged.count == 15, "merged count")
        try require(
            merged.filter { $0.availability?.is24Hours == true }.count == 11,
            "merged 24-hour count"
        )
        try require(
            merged.filter { $0.availability?.is24Hours == false }.count == 4,
            "merged scheduled count"
        )
        try require(scheduledIntervalProbes == 35, "scheduled interval probe count")
        try require(gapProbes == 7, "scheduled gap probe count")

        let commonMidnight = Calendar.hongKong.startOfDay(for: commonReference)
        var filter = ClinicSearchFilter()
        try require(filter.results(from: merged, at: commonMidnight).count == 15, "all filter")
        filter.availability = .open24Hours
        try require(filter.results(from: merged, at: commonMidnight).count == 11, "24-hour filter")
        filter.availability = .nightService
        try require(filter.results(from: merged, at: commonMidnight).count == 11, "night filter")
        filter.availability = .openNow
        try require(filter.results(from: merged, at: commonMidnight).count == 11, "open filter")

        print(
            "{\"manifestCompatibility\":true,\"productionApplied\":false,"
            + "\"v1Total\":11,\"v1TwentyFourHours\":10,\"v1Scheduled\":1,"
            + "\"v2Total\":4,\"v2TwentyFourHours\":1,\"v2Scheduled\":3,"
            + "\"mergedTotal\":15,\"mergedTwentyFourHours\":11,"
            + "\"mergedScheduled\":4,\"filterAll\":15,"
            + "\"filterOpen24Hours\":11,\"filterNightService\":11,"
            + "\"filterOpenNow\":11,\"scheduledIntervalProbes\":35,"
            + "\"gapProbes\":7}"
        )
    }

    private static func distribution(_ clinics: [HoursClinic]) -> (Int, Int, Int) {
        let allDay = clinics.filter(\.is24Hours).count
        return (clinics.count, allDay, clinics.count - allDay)
    }

    private static func project(
        _ manifest: HoursManifest,
        migrationID: String,
        commonReference: Date,
        scheduledIntervalProbes: inout Int,
        gapProbes: inout Int
    ) throws -> [VetClinic] {
        try manifest.clinics.map { source in
            let availability = ClinicAvailability(
                schemaVersion: manifest.schemaVersion,
                migrationId: migrationID,
                timeZoneIdentifier: manifest.timeZoneIdentifier,
                weeklyHours: source.weeklyHours,
                is24Hours: source.is24Hours,
                offersNightService: source.offersNightService,
                displayLabel: source.displayLabel,
                serviceNote: source.serviceNote,
                sourceURL: source.sourceURL,
                sourceName: source.sourceName,
                verifiedAt: manifest.verifiedAt,
                expiresAt: manifest.expiresAt
            )
            try require(availability.weeklyHours == source.weeklyHours, "hours projection")
            try require(availability.isCurrent(at: commonReference), "current projection")

            let clinic = VetClinic(
                id: source.clinicID,
                name: source.expectedName,
                address: "Hong Kong",
                coordinate: ClinicCoordinate(latitude: 22.3, longitude: 114.2),
                catalogRegion: "HK",
                phone: "",
                website: nil,
                openingHours: [:],
                availability: availability,
                services: [],
                avgRating: 0,
                reviewCount: 0,
                priceLevel: 0,
                images: [],
                tags: [],
                createdAt: commonReference,
                updatedAt: commonReference,
                reportedBy: "manifest-compatibility-harness",
                verified: false
            )
            try require(
                clinic.hasCurrentAvailability(at: commonReference),
                "clinic current projection"
            )
            if source.is24Hours {
                try require(
                    clinic.operatingStatus(at: commonReference)
                        == .open24Hours(label: source.displayLabel),
                    "24-hour status"
                )
                try require(
                    clinic.availabilityLabel(at: commonReference) == source.displayLabel,
                    "24-hour label"
                )
            } else {
                for availabilityFilter in [
                    ClinicSearchFilter.Availability.open24Hours,
                    .nightService
                ] {
                    var filter = ClinicSearchFilter()
                    filter.availability = availabilityFilter
                    try require(
                        filter.results(from: [clinic], at: commonReference).isEmpty,
                        "scheduled filter classification"
                    )
                }
                try probeScheduledIntervals(
                    source.weeklyHours,
                    for: clinic,
                    relativeTo: commonReference,
                    scheduledIntervalProbes: &scheduledIntervalProbes,
                    gapProbes: &gapProbes
                )
            }
            return clinic
        }
    }

    private static func probeScheduledIntervals(
        _ weeklyHours: [String: [ClinicHoursInterval]],
        for clinic: VetClinic,
        relativeTo reference: Date,
        scheduledIntervalProbes: inout Int,
        gapProbes: inout Int
    ) throws {
        let calendar = Calendar.hongKong
        let referenceMidnight = calendar.startOfDay(for: reference)
        let referenceDayIndex = calendar.component(.weekday, from: referenceMidnight) - 1
        for (dayIndex, weekday) in weekdays.enumerated() {
            guard let targetDay = calendar.date(
                byAdding: .day,
                value: (dayIndex - referenceDayIndex + 7) % 7,
                to: referenceMidnight
            ) else {
                throw HarnessError.failed("scheduled probe day")
            }
            let intervals = weeklyHours[weekday] ?? []
            let parsed = try intervals.map { interval -> (opens: Int, closes: Int) in
                guard
                    let opens = minuteOfDay(interval.opensAt),
                    let closes = minuteOfDay(interval.closesAt)
                else {
                    throw HarnessError.failed("scheduled interval time")
                }
                let duration = closes > opens
                    ? closes - opens
                    : 24 * 60 - opens + closes
                guard
                    let start = calendar.date(
                        byAdding: .minute,
                        value: opens,
                        to: targetDay
                    ),
                    let midpoint = calendar.date(
                        byAdding: .minute,
                        value: duration / 2,
                        to: start
                    )
                else {
                    throw HarnessError.failed("scheduled midpoint date")
                }
                try require(clinic.isOpen(at: midpoint), "scheduled midpoint closed")
                try require(
                    clinic.availabilityLabel(at: midpoint)?.hasPrefix("營業中 · 至 ") == true,
                    "scheduled label"
                )
                scheduledIntervalProbes += 1
                return (opens, closes)
            }.sorted { $0.opens < $1.opens }

            for (previous, current) in zip(parsed, parsed.dropFirst()) {
                // An overnight interval ends on the following day, so it must
                // never be interpreted as creating a same-day gap.
                guard
                    previous.closes > previous.opens,
                    current.opens > previous.closes,
                    let gapMidpoint = calendar.date(
                        byAdding: .minute,
                        value: previous.closes
                            + (current.opens - previous.closes) / 2,
                        to: targetDay
                    )
                else {
                    continue
                }
                try require(!clinic.isOpen(at: gapMidpoint), "scheduled gap is open")
                try require(
                    clinic.availabilityLabel(at: gapMidpoint)?
                        .hasPrefix("營業中 · 至 ") != true,
                    "scheduled gap has open label"
                )
                gapProbes += 1
            }
        }
    }

    private static func minuteOfDay(_ value: String) -> Int? {
        let bytes = Array(value.utf8)
        guard
            bytes.count == 5,
            bytes[2] == 58,
            bytes.enumerated().allSatisfy({ index, byte in
                index == 2 || (48...57).contains(byte)
            })
        else {
            return nil
        }
        return Int(bytes[0] - 48) * 600
            + Int(bytes[1] - 48) * 60
            + Int(bytes[3] - 48) * 10
            + Int(bytes[4] - 48)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw HarnessError.failed(message) }
    }
}

private extension Calendar {
    static var hongKong: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        return calendar
    }
}

private enum HarnessError: Error, CustomStringConvertible {
    case usage
    case failed(String)

    var description: String {
        switch self {
        case .usage:
            return "usage: clinic_availability_manifest_compatibility_harness <v1.json> <v2.json>"
        case .failed(let message):
            return "manifest compatibility failed: \(message)"
        }
    }
}
