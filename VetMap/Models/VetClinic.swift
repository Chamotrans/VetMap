import Foundation

struct VetClinic: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var address: String
    /// `nil` means the directory entry has no reliable geocode yet. It may
    /// still be listed, but must not be shown as a map pin or used for routing.
    var coordinate: ClinicCoordinate?
    /// Server-controlled region marker for curated directory entries.
    /// User submissions leave this nil until moderation publishes them.
    var catalogRegion: String? = nil
    var phone: String
    var website: URL?
    var openingHours: [String: String]
    /// Server-curated operating data backed by a clinic's official source.
    /// User submissions must not populate this field.
    var availability: ClinicAvailability? = nil
    var services: [String]
    var avgRating: Double
    var reviewCount: Int
    var priceLevel: Int
    var images: [URL]
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var reportedBy: String
    var verified: Bool
}

struct ClinicAvailability: Codable, Equatable {
    let schemaVersion: Int
    let migrationId: String
    let timeZoneIdentifier: String
    let weeklyHours: [String: [ClinicHoursInterval]]
    let is24Hours: Bool
    let offersNightService: Bool
    let displayLabel: String
    let serviceNote: String
    let sourceURL: URL
    let sourceName: String
    let verifiedAt: Date
    let expiresAt: Date
}

struct ClinicHoursInterval: Codable, Equatable {
    /// Local clinic time in 24-hour `HH:mm` format.
    let opensAt: String
    /// Local clinic time in 24-hour `HH:mm` format. A value less than or equal
    /// to `opensAt` means the interval continues into the following day.
    let closesAt: String
}

enum ClinicOperatingStatus: Equatable {
    case open24Hours(label: String)
    case open(until: Date)
    case closed
    case unavailable
}

extension VetClinic {
    /// A coordinate is mappable only when it is finite and inside the Hong Kong
    /// service boundary used by the submission and search flows.
    var hasReliableHongKongCoordinate: Bool {
        guard let coordinate else { return false }
        return coordinate.latitude.isFinite
            && coordinate.longitude.isFinite
            && (22.1...22.6).contains(coordinate.latitude)
            && (113.8...114.5).contains(coordinate.longitude)
    }

    func operatingStatus(at date: Date = Date()) -> ClinicOperatingStatus {
        guard let availability, availability.isCurrent(at: date) else {
            return .unavailable
        }

        if availability.is24Hours {
            let label = availability.displayLabel
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .open24Hours(label: label.isEmpty ? "24 小時" : label)
        }

        guard
            let calendar = availability.calendar,
            let intervalEnd = availability.openIntervalEnd(at: date, calendar: calendar)
        else {
            return .closed
        }
        return .open(until: intervalEnd)
    }

    func isOpen(at date: Date = Date()) -> Bool {
        switch operatingStatus(at: date) {
        case .open24Hours, .open:
            return true
        case .closed, .unavailable:
            return false
        }
    }

    func hasCurrentNightService(at date: Date = Date()) -> Bool {
        availability?.isCurrent(at: date) == true
            && availability?.offersNightService == true
    }

    func hasCurrentAvailability(at date: Date = Date()) -> Bool {
        availability?.isCurrent(at: date) == true
    }

    func availabilityLabel(at date: Date = Date()) -> String? {
        switch operatingStatus(at: date) {
        case .open24Hours(let label):
            return label
        case .open(let closingTime):
            return "營業中 · 至 \(formattedClinicTime(closingTime))"
        case .closed:
            return hasCurrentNightService(at: date) ? "設夜診" : "休息中"
        case .unavailable:
            return nil
        }
    }

    func availabilitySortRank(at date: Date = Date()) -> Int {
        switch operatingStatus(at: date) {
        case .open24Hours:
            return 0
        case .open:
            return 1
        case .closed where hasCurrentNightService(at: date):
            return 2
        case .closed:
            return 3
        case .unavailable:
            return 4
        }
    }

    private func formattedClinicTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_HK")
        formatter.timeZone = availability.flatMap {
            TimeZone(identifier: $0.timeZoneIdentifier)
        } ?? TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

extension ClinicAvailability {
    private static let weekdayKeys = [
        "sun", "mon", "tue", "wed", "thu", "fri", "sat"
    ]

    fileprivate var calendar: Calendar? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func isCurrent(at date: Date) -> Bool {
        verifiedAt <= date
            && date < expiresAt
            && calendar != nil
    }

    fileprivate func openIntervalEnd(
        at date: Date,
        calendar: Calendar
    ) -> Date? {
        let startOfToday = calendar.startOfDay(for: date)
        let weekdayIndex = calendar.component(.weekday, from: date) - 1
        guard Self.weekdayKeys.indices.contains(weekdayIndex) else {
            return nil
        }

        let todayKey = Self.weekdayKeys[weekdayIndex]
        let previousKey = Self.weekdayKeys[
            (weekdayIndex + Self.weekdayKeys.count - 1)
                % Self.weekdayKeys.count
        ]

        var candidateEnds: [Date] = []
        for interval in weeklyHours[todayKey] ?? [] {
            if let range = interval.dateRange(
                relativeTo: startOfToday,
                calendar: calendar
            ), range.contains(date) {
                candidateEnds.append(range.upperBound)
            }
        }

        guard
            let startOfYesterday = calendar.date(
                byAdding: .day,
                value: -1,
                to: startOfToday
            )
        else {
            return candidateEnds.min()
        }
        for interval in weeklyHours[previousKey] ?? []
            where interval.continuesIntoFollowingDay {
            if let range = interval.dateRange(
                relativeTo: startOfYesterday,
                calendar: calendar
            ), range.contains(date) {
                candidateEnds.append(range.upperBound)
            }
        }

        return candidateEnds.min()
    }
}

private extension ClinicHoursInterval {
    var continuesIntoFollowingDay: Bool {
        guard let opens = minuteOfDay(opensAt), let closes = minuteOfDay(closesAt) else {
            return false
        }
        return closes <= opens
    }

    func dateRange(
        relativeTo startOfDay: Date,
        calendar: Calendar
    ) -> Range<Date>? {
        guard
            let opens = minuteOfDay(opensAt),
            let closes = minuteOfDay(closesAt),
            let start = calendar.date(
                byAdding: .minute,
                value: opens,
                to: startOfDay
            ),
            let sameDayEnd = calendar.date(
                byAdding: .minute,
                value: closes,
                to: startOfDay
            )
        else {
            return nil
        }
        let end: Date
        if closes <= opens {
            guard let followingDayEnd = calendar.date(
                byAdding: .day,
                value: 1,
                to: sameDayEnd
            ) else {
                return nil
            }
            end = followingDayEnd
        } else {
            end = sameDayEnd
        }
        guard start < end else { return nil }
        return start..<end
    }

    func minuteOfDay(_ value: String) -> Int? {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard
            parts.count == 2,
            let hour = Int(parts[0]),
            let minute = Int(parts[1]),
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }
        return hour * 60 + minute
    }
}
