import Foundation

enum ClinicAvailabilityFeedbackReason: String, CaseIterable, Identifiable {
    case differentHours = "營業時間不同"
    case closedOrSuspended = "暫停營業／已結業"
    case otherAvailabilityIssue = "其他營業資料問題"
    case notOpen24Hours = "並非24小時"
    case nightOrEmergencyChanged = "夜診／急症服務有變"

    var id: String { rawValue }
}

struct ClinicAvailabilityFeedbackTicket: Equatable {
    let reason: ClinicAvailabilityFeedbackReason
    let migrationID: String
    let sourceName: String
    let verifiedDate: String

    var canonicalReportReason: String {
        "營業資料回報｜原因：\(reason.rawValue)｜migrationId：\(migrationID)"
            + "｜來源名稱：\(sourceName)｜核實日期：\(verifiedDate)"
    }

    func verificationTicket(clinicID: String, clinicName: String) -> String {
        let safeClinicID = ClinicAvailabilityFeedback.cleanForExport(
            clinicID,
            fallback: "診所 ID 待核實"
        )
        let safeClinicName = ClinicAvailabilityFeedback.cleanForExport(
            clinicName,
            fallback: "診所名稱待核實"
        )
        return [
            "VetMap 營業資料重新核實工單",
            "診所 ID：\(safeClinicID)",
            "診所名稱：\(safeClinicName)",
            "回報原因：\(reason.rawValue)",
            "migrationId：\(migrationID)",
            "來源名稱：\(sourceName)",
            "原核實日期：\(verifiedDate)",
            "處理要求：需重新核實，不可直接套用回報內容"
        ].joined(separator: "\n")
    }
}

enum ClinicAvailabilityFeedbackClassification: Equatable {
    case structured(ClinicAvailabilityFeedbackTicket)
    case malformed(String)
    case general(String)

    var isAvailabilityFeedback: Bool {
        switch self {
        case .structured, .malformed: true
        case .general: false
        }
    }

    var allowsTakeDown: Bool {
        !isAvailabilityFeedback
    }
}

enum ClinicAvailabilityFeedback {
    private static let reportPrefix = "營業資料回報"
    private static let reservedReportPrefix = "營業資料回報｜"
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
        guard
            reason == selectedReason.rawValue,
            isSafeMigrationIdentifier(migrationID),
            isValidVerifiedDate(verifiedDate)
        else {
            return nil
        }
        let ticket = ClinicAvailabilityFeedbackTicket(
            reason: selectedReason,
            migrationID: migrationID,
            sourceName: sourceName,
            verifiedDate: verifiedDate
        )
        let report = ticket.canonicalReportReason
        return report.count <= 500 ? report : nil
    }

    static func classify(
        _ reportReason: String,
        isClinicReport: Bool = true
    ) -> ClinicAvailabilityFeedbackClassification {
        guard isClinicReport else {
            return .general(reportReason)
        }
        guard reservedPrefixSecurityProbe(reportReason).hasPrefix(reservedReportPrefix) else {
            return .general(reportReason)
        }
        guard let ticket = parse(reportReason) else {
            return .malformed(reportReason)
        }
        return .structured(ticket)
    }

    private static func parse(_ reportReason: String) -> ClinicAvailabilityFeedbackTicket? {
        guard reportReason.count <= 500 else { return nil }
        let fields = reportReason.components(separatedBy: "｜")
        guard
            fields.count == 5,
            fields[0] == reportPrefix,
            let reason = exactValue(in: fields[1], prefix: "原因：")
                .flatMap(ClinicAvailabilityFeedbackReason.init(rawValue:)),
            let migrationID = exactValue(in: fields[2], prefix: "migrationId："),
            isSafeMigrationIdentifier(migrationID),
            let sourceName = exactValue(in: fields[3], prefix: "來源名稱："),
            isSafeParsedSourceName(sourceName),
            let verifiedDate = exactValue(in: fields[4], prefix: "核實日期："),
            isValidVerifiedDate(verifiedDate)
        else {
            return nil
        }

        let ticket = ClinicAvailabilityFeedbackTicket(
            reason: reason,
            migrationID: migrationID,
            sourceName: sourceName,
            verifiedDate: verifiedDate
        )
        guard ticket.canonicalReportReason == reportReason else { return nil }
        return ticket
    }

    private static func exactValue(in field: String, prefix: String) -> String? {
        guard field.hasPrefix(prefix) else { return nil }
        let value = String(field.dropFirst(prefix.count))
        return value.isEmpty ? nil : value
    }

    private static func safeSourceName(_ value: String) -> String {
        let cleaned = clean(value, limit: 160)
        let probe = sourceSecurityProbe(cleaned)
        let lowercased = probe.normalized.lowercased()
        if lowercased.contains("://")
            || lowercased.contains("www.")
            || lowercased.contains("http")
            || containsUnicodeBareDomain(lowercased)
            || containsPhoneLikeSequence(probe.normalized)
            || probe.containsRiskyConfusable {
            return "官方來源"
        }
        return cleaned.isEmpty ? "官方來源" : cleaned
    }

    private static func reservedPrefixSecurityProbe(_ value: String) -> String {
        let withoutLeadingIgnorables = String(
            value.unicodeScalars.drop(while: isLeadingSecurityIgnorable)
        )
        let compatibilityNormalized = withoutLeadingIgnorables
            .precomposedStringWithCompatibilityMapping
        let normalizedLeading = compatibilityNormalized.unicodeScalars.drop(
            while: isLeadingSecurityIgnorable
        )
        return normalizedLeading.map { scalar in
            isVerticalBarConfusable(scalar) ? "｜" : String(scalar)
        }.joined()
    }

    private static func isLeadingSecurityIgnorable(_ scalar: Unicode.Scalar) -> Bool {
        if CharacterSet.whitespacesAndNewlines.contains(scalar) {
            return true
        }
        switch scalar.properties.generalCategory {
        case .control, .format, .lineSeparator, .paragraphSeparator, .spaceSeparator:
            return true
        default:
            return false
        }
    }

    private static func isVerticalBarConfusable(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x7C,   // vertical line
             0x1C0,  // Latin letter dental click
             0x2223, // divides
             0x2502, // box drawings light vertical
             0x2758, // light vertical bar
             0xFF5C: // fullwidth vertical line
            return true
        default:
            return false
        }
    }

    private static func sourceSecurityProbe(
        _ value: String
    ) -> (normalized: String, containsRiskyConfusable: Bool) {
        let compatibilityNormalized = value.precomposedStringWithCompatibilityMapping
        var containsRiskyConfusable = false
        let normalized = compatibilityNormalized.unicodeScalars.map { scalar -> String in
            switch scalar.value {
            case 0x3002, // ideographic full stop
                 0xFF61, // halfwidth ideographic full stop
                 0x2024, // one dot leader
                 0x22C5: // dot operator
                return "."
            case 0x2044, // fraction slash
                 0x2215, // division slash
                 0x29F8: // big solidus
                containsRiskyConfusable = true
                return "/"
            case 0x2236, // ratio
                 0xA789: // modifier letter colon
                containsRiskyConfusable = true
                return ":"
            case 0x1C0,  // Latin letter dental click
                 0x2223, // divides
                 0x2502, // box drawings light vertical
                 0x2758: // light vertical bar
                containsRiskyConfusable = true
                return "|"
            default:
                return String(scalar)
            }
        }.joined()
        return (normalized, containsRiskyConfusable)
    }

    private static func containsUnicodeBareDomain(_ value: String) -> Bool {
        let candidates = value.split { character in
            !character.unicodeScalars.allSatisfy { scalar in
                CharacterSet.alphanumerics.contains(scalar)
                    || scalar.value == 0x2D
                    || scalar.value == 0x2E
            }
        }

        for candidate in candidates {
            let labels = candidate.split(separator: ".", omittingEmptySubsequences: false)
            guard labels.count >= 2 else { continue }
            for topLevelIndex in 1..<labels.count where isReasonableTopLevelLabel(labels[topLevelIndex]) {
                if isValidDomainLabel(labels[topLevelIndex - 1]) {
                    return true
                }
            }
        }
        return false
    }

    private static func isValidDomainLabel(_ label: Substring) -> Bool {
        let scalars = label.unicodeScalars
        guard
            !scalars.isEmpty,
            scalars.count <= 63,
            let first = scalars.first,
            let last = scalars.last,
            CharacterSet.alphanumerics.contains(first),
            CharacterSet.alphanumerics.contains(last)
        else {
            return false
        }
        return scalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0) || $0.value == 0x2D
        }
    }

    private static func isReasonableTopLevelLabel(_ label: Substring) -> Bool {
        guard isValidDomainLabel(label) else { return false }
        let normalized = label.lowercased()
        let bytes = Array(normalized.utf8)
        if bytes.count >= 2, bytes.count <= 63,
           bytes.allSatisfy({ (97...122).contains($0) }) {
            return true
        }
        if normalized.hasPrefix("xn--"), bytes.count >= 6, bytes.count <= 63 {
            return true
        }
        return [
            "香港", "中國", "中国", "台灣", "台湾"
        ].contains(normalized)
    }

    private static func containsPhoneLikeSequence(_ value: String) -> Bool {
        value.filter(\.isNumber).count >= 7
    }

    private static func isSafeParsedSourceName(_ value: String) -> Bool {
        value == clean(value, limit: 160)
            && safeSourceName(value) == value
            && value.unicodeScalars.contains {
                CharacterSet.alphanumerics.contains($0)
            }
    }

    private static func isSafeMigrationIdentifier(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        let prefix = Array("hk-clinic-hours-".utf8)
        guard
            bytes.count <= 160,
            bytes.starts(with: prefix),
            bytes.count > prefix.count
        else {
            return false
        }
        let suffix = bytes.dropFirst(prefix.count)
        guard
            let first = suffix.first,
            let last = suffix.last,
            isASCIIAlphanumeric(first),
            isASCIIAlphanumeric(last)
        else {
            return false
        }
        return suffix.allSatisfy {
            isASCIIAlphanumeric($0) || $0 == 45
        }
    }

    private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
            || (65...90).contains(byte)
            || (97...122).contains(byte)
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
        let formatter = verifiedDateFormatter()
        return formatter.string(from: date)
    }

    private static func isValidVerifiedDate(_ value: String) -> Bool {
        guard value.utf8.count == 10 else { return false }
        let formatter = verifiedDateFormatter()
        guard let date = formatter.date(from: value) else { return false }
        return formatter.string(from: date) == value
    }

    private static func verifiedDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    fileprivate static func cleanForExport(_ value: String, fallback: String) -> String {
        let cleaned = clean(value, limit: 160)
        return cleaned.isEmpty ? fallback : cleaned
    }
}
