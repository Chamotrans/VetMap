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
            "+852 2123 4567",
            "ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ",
            "診所。香港",
            "診所.香港",
            "例子.com",
            "官方∣來源",
            "官方│來源"
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
        let ordinaryChineseSentence = "香港診所。官方網站資料"
        let ordinaryReport = ClinicAvailabilityFeedback.reportReason(
            .differentHours,
            availability: availability(
                is24Hours: true,
                sourceName: ordinaryChineseSentence
            ),
            at: now
        )!
        check(ordinaryReport.contains("來源名稱：\(ordinaryChineseSentence)"))
        guard case let .structured(ordinaryTicket) = ClinicAvailabilityFeedback.classify(
            ordinaryReport
        ) else {
            preconditionFailure("ordinary Chinese sentence was misclassified as a domain")
        }
        check(ordinaryTicket.sourceName == ordinaryChineseSentence)

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

        for reason in ClinicAvailabilityFeedbackReason.allCases {
            let canonical = ClinicAvailabilityFeedback.reportReason(
                reason,
                availability: allDay,
                at: now
            )!
            let classification = ClinicAvailabilityFeedback.classify(canonical)
            guard case let .structured(ticket) = classification else {
                preconditionFailure("canonical availability report did not parse")
            }
            check(ticket.reason == reason)
            check(ticket.migrationID == "hk-clinic-hours-feedback-v1")
            check(ticket.sourceName == "官方網站")
            check(ticket.verifiedDate == "2026-01-01")
            check(ticket.canonicalReportReason == canonical)
            check(!classification.allowsTakeDown)
        }

        let malformedReasons = [
            "營業資料回報｜原因：營業時間不同",
            "營業資料回報｜migrationId：hk-clinic-hours-feedback-v1｜原因：營業時間不同｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：任意原因｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：unsafe｜來源名稱：官方網站｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：clinic.example.com｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：ｈｔｔｐｓ：／／ｅｘａｍｐｌｅ．ｃｏｍ｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：診所。香港｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：診所.香港｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：例子.com｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：官方∣來源｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：官方│來源｜核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：官方網站｜核實日期：2026-02-30",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：官方網站｜核實日期：2026-01-01｜額外：欄位",
            "營業資料回報|原因：營業時間不同|migrationId：hk-clinic-hours-feedback-v1|來源名稱：官方網站|核實日期：2026-01-01",
            "營業資料回報｜原因：營業時間不同｜migrationId：hk-clinic-hours-feedback-v1｜來源名稱：\(String(repeating: "官", count: 501))｜核實日期：2026-01-01"
        ]
        for malformedReason in malformedReasons {
            let classification = ClinicAvailabilityFeedback.classify(malformedReason)
            guard case let .malformed(raw) = classification else {
                preconditionFailure("reserved availability prefix did not fail closed")
            }
            check(raw == malformedReason)
            check(classification.isAvailabilityFeedback)
            check(!classification.allowsTakeDown)
        }

        let dirtyReservedPrefixes = [
            " " + report,
            "\n" + report,
            "\u{00A0}" + report,
            "\u{FEFF}" + report,
            "\u{2060}" + report,
            report.replacingOccurrences(of: "｜", with: "∣", options: [], range: report.range(of: "｜")),
            report.replacingOccurrences(of: "｜", with: "│", options: [], range: report.range(of: "｜"))
        ]
        for dirtyReason in dirtyReservedPrefixes {
            let clinicClassification = ClinicAvailabilityFeedback.classify(dirtyReason)
            guard case let .malformed(raw) = clinicClassification else {
                preconditionFailure("dirty reserved prefix must fail closed")
            }
            check(raw == dirtyReason)
            check(!clinicClassification.allowsTakeDown)

            let nonClinicClassification = ClinicAvailabilityFeedback.classify(
                dirtyReason,
                isClinicReport: false
            )
            guard case let .general(raw) = nonClinicClassification else {
                preconditionFailure("non-clinic dirty prefix must remain general")
            }
            check(raw == dirtyReason)
            check(nonClinicClassification.allowsTakeDown)
        }

        for generalReason in ["資料不實", "營業資料回報", "營業資料回報唔準"] {
            let general = ClinicAvailabilityFeedback.classify(generalReason)
            guard case let .general(raw) = general else {
                preconditionFailure("general report misclassified")
            }
            check(raw == generalReason)
            check(!general.isAvailabilityFeedback)
            check(general.allowsTakeDown)
        }
        let reviewPrefix = ClinicAvailabilityFeedback.classify(
            report,
            isClinicReport: false
        )
        guard case .general = reviewPrefix else {
            preconditionFailure("non-clinic report was classified as availability")
        }
        check(reviewPrefix.allowsTakeDown)

        guard case let .structured(ticket) = ClinicAvailabilityFeedback.classify(report) else {
            preconditionFailure("sanitized report did not parse")
        }
        let verificationTicket = ticket.verificationTicket(
            clinicID: "clinic-001",
            clinicName: "香港獸醫診所"
        )
        check(
            verificationTicket == "VetMap 營業資料重新核實工單\n"
                + "診所 ID：clinic-001\n"
                + "診所名稱：香港獸醫診所\n"
                + "回報原因：營業時間不同\n"
                + "migrationId：hk-clinic-hours-feedback-v1\n"
                + "來源名稱：官方 網站\n"
                + "原核實日期：2026-01-01\n"
                + "處理要求：需重新核實，不可直接套用回報內容"
        )
        for privateValue in [
            "report-id-private",
            "reporter-uid-private",
            "2123 4567",
            "https://example.com/private-hours"
        ] {
            check(!verificationTicket.contains(privateValue))
        }

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
