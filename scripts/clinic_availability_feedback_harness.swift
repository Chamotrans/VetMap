import Foundation

@main
struct ClinicAvailabilityFeedbackHarness {
    private static let now = Date(timeIntervalSince1970: 1_775_102_400)
    private static let verifiedAt = Date(timeIntervalSince1970: 1_767_225_600)
    private static let expiresAt = Date(timeIntervalSince1970: 1_775_577_600)

    static func main() {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool) {
            precondition(condition())
            passed += 1
        }

        let scheduled = availability()
        let allDay = availability(is24Hours: true)
        let night = availability(offersNightService: true)
        check(
            ClinicAvailabilityFeedback.reasons(for: scheduled, at: now)
                == [.differentHours, .closedOrSuspended, .otherAvailabilityIssue]
        )
        check(
            ClinicAvailabilityFeedback.reasons(for: allDay, at: now)
                == [
                    .differentHours,
                    .closedOrSuspended,
                    .otherAvailabilityIssue,
                    .notOpen24Hours,
                    .nightOrEmergencyChanged
                ]
        )
        check(
            ClinicAvailabilityFeedback.reasons(for: night, at: now)
                == [
                    .differentHours,
                    .closedOrSuspended,
                    .otherAvailabilityIssue,
                    .nightOrEmergencyChanged
                ]
        )
        check(
            ClinicAvailabilityFeedback.reasons(for: allDay, at: expiresAt).isEmpty
        )

        let sanitized = availability(
            is24Hours: true,
            sourceName: "官方\n\u{0000}網站"
        )
        let report = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: sanitized,
            at: now
        )!
        check(
            report == "營業資料回報｜原因：營業時間不同"
                + "｜migrationId：hk-clinic-hours-feedback-v1"
                + "｜來源名稱：官方 網站｜核實日期：2026-01-01"
        )
        check(!report.contains("\n") && !report.contains("\u{0000}"))
        check(!report.contains(sanitized.sourceURL.absoluteString))
        check(!report.contains("2123 4567"))
        check(
            ClinicAvailabilityFeedback.reportReason(
                .notOpen24Hours,
                availability: scheduled,
                at: now
            ) == nil
        )

        for sensitiveSource in [
            "https://example.com/hours",
            "clinic.example.com",
            "2123/4567",
            "(852) 2123.4567",
            "+852 2123 4567"
        ] {
            let sensitiveReport = ClinicAvailabilityFeedback.reportReason(
                .differentHours,
                availability: availability(
                    is24Hours: true,
                    sourceName: sensitiveSource
                ),
                at: now
            )!
            check(sensitiveReport.contains("來源名稱：官方來源"))
            check(!sensitiveReport.contains(sensitiveSource))
        }
        let injectedReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: availability(
                is24Hours: true,
                sourceName: "官方｜來源|偽造"
            ),
            at: now
        )!
        check(injectedReport.contains("來源名稱：官方 來源 偽造"))
        check(!injectedReport.contains("來源名稱：官方｜來源|偽造"))

        let longReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: availability(
                is24Hours: true,
                sourceName: String(repeating: "官", count: 1_000)
            ),
            at: now
        )!
        check(longReport.count <= 500)

        print("{\"clinicAvailabilityFeedback\":true,\"passed\":\(passed)}")
    }

    private static func availability(
        is24Hours: Bool = false,
        offersNightService: Bool? = nil,
        sourceName: String = "官方網站"
    ) -> ClinicAvailability {
        let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        let weeklyHours: [String: [ClinicHoursInterval]] = is24Hours
            ? [:]
            : Dictionary(uniqueKeysWithValues: weekdays.map { ($0, []) })
        return ClinicAvailability(
            schemaVersion: 1,
            migrationId: "hk-clinic-hours-feedback-v1",
            timeZoneIdentifier: "Asia/Hong_Kong",
            weeklyHours: weeklyHours,
            is24Hours: is24Hours,
            offersNightService: offersNightService ?? is24Hours,
            displayLabel: is24Hours ? "24 小時" : "",
            serviceNote: "官方營業資料",
            sourceURL: URL(string: "https://example.com/private-hours")!,
            sourceName: sourceName,
            verifiedAt: verifiedAt,
            expiresAt: expiresAt
        )
    }
}
