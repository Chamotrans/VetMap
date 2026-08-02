import Foundation

enum ClinicAvailabilityFeedbackReason: String, CaseIterable, Identifiable {
    case differentHours = "營業時間不同"
    case closedOrSuspended = "暫停營業／已結業"
    case otherAvailabilityIssue = "其他營業資料問題"
    case notOpen24Hours = "並非24小時"
    case nightOrEmergencyChanged = "夜診／急症服務有變"

    var id: String { rawValue }
}

enum ClinicAvailabilityFeedback {
    private static let baseReasons: [ClinicAvailabilityFeedbackReason] = [
        .differentHours,
        .closedOrSuspended,
        .otherAvailabilityIssue
    ]

    static func reasons(
        for availability: ClinicAvailability?,
        at date: Date = Date()
    ) -> [ClinicAvailabilityFeedbackReason] {
        guard let availability, availability.isCurrent(at: date) else {
            return []
        }
        var result = baseReasons
        if availability.is24Hours {
            result.append(.notOpen24Hours)
        }
        if availability.offersNightService {
            result.append(.nightOrEmergencyChanged)
        }
        return result
    }

    static func reportReason(
        _ selectedReason: ClinicAvailabilityFeedbackReason,
        availability: ClinicAvailability,
        at date: Date = Date()
    ) -> String? {
        guard reasons(for: availability, at: date).contains(selectedReason) else {
            return nil
        }
        let reason = clean(selectedReason.rawValue, limit: 80)
        let migrationID = clean(availability.migrationId, limit: 160)
        let sourceName = safeSourceName(availability.sourceName)
        let verifiedDate = formattedDate(availability.verifiedAt)
        let report = "營業資料回報｜原因：\(reason)｜migrationId：\(migrationID)"
            + "｜來源名稱：\(sourceName)｜核實日期：\(verifiedDate)"
        return String(report.prefix(500))
    }

    private static func safeSourceName(_ value: String) -> String {
        let cleaned = clean(value, limit: 160)
        let lowercased = cleaned.lowercased()
        if lowercased.contains("://")
            || lowercased.contains("www.")
            || lowercased.contains("http")
            || containsBareDomain(lowercased)
            || containsPhoneLikeSequence(cleaned) {
            return "官方來源"
        }
        return cleaned.isEmpty ? "官方來源" : cleaned
    }

    private static func containsBareDomain(_ value: String) -> Bool {
        value.range(
            of: #"\b(?:[a-z0-9-]+\.)+[a-z]{2,63}\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func containsPhoneLikeSequence(_ value: String) -> Bool {
        value.filter(\.isNumber).count >= 7
    }

    private static func clean(_ value: String, limit: Int) -> String {
        let withoutControls = value.unicodeScalars.map { scalar -> String in
            if scalar.value == 0x7C || scalar.value == 0xFF5C {
                return " "
            }
            switch scalar.properties.generalCategory {
            case .control, .format, .lineSeparator, .paragraphSeparator:
                return " "
            default:
                return String(scalar)
            }
        }.joined()
        let collapsed = withoutControls
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        return String(collapsed.prefix(limit))
    }

    private static func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
