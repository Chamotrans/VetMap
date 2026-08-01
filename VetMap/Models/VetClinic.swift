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
    private static let maximumVerificationWindow: TimeInterval = 100 * 24 * 60 * 60
    private static let minutesPerDay = 24 * 60
    private static let minutesPerWeek = 7 * minutesPerDay

    fileprivate var calendar: Calendar? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    func isCurrent(at date: Date) -> Bool {
        guard
            schemaVersion == 1,
            hasSafeMigrationIdentifier,
            timeZoneIdentifier == "Asia/Hong_Kong",
            calendar != nil,
            verifiedAt < expiresAt,
            expiresAt.timeIntervalSince(verifiedAt)
                <= Self.maximumVerificationWindow,
            verifiedAt <= date,
            date < expiresAt,
            sourceURL.scheme?.lowercased() == "https",
            sourceURL.host?.isEmpty == false,
            hasVisibleAlphanumeric(sourceName),
            hasVisibleAlphanumeric(serviceNote)
        else {
            return false
        }

        if is24Hours {
            return offersNightService
                && hasVisibleAlphanumeric(displayLabel)
                && weeklyHours.isEmpty
        }
        return hasValidScheduledHours
    }

    private var hasSafeMigrationIdentifier: Bool {
        let bytes = Array(migrationId.utf8)
        let prefix = Array("hk-clinic-hours-".utf8)
        guard
            bytes.starts(with: prefix),
            bytes.count > prefix.count
        else {
            return false
        }
        let suffix = bytes.dropFirst(prefix.count)
        guard
            let first = suffix.first,
            let last = suffix.last,
            Self.isASCIIAlphanumeric(first),
            Self.isASCIIAlphanumeric(last)
        else {
            return false
        }
        return suffix.allSatisfy {
            Self.isASCIIAlphanumeric($0) || $0 == 45
        }
    }

    private func hasVisibleAlphanumeric(_ value: String) -> Bool {
        value.unicodeScalars.contains {
            CharacterSet.alphanumerics.contains($0)
        }
    }

    private static func isASCIIAlphanumeric(_ byte: UInt8) -> Bool {
        (48...57).contains(byte)
            || (65...90).contains(byte)
            || (97...122).contains(byte)
    }

    private var hasValidScheduledHours: Bool {
        guard Set(weeklyHours.keys) == Set(Self.weekdayKeys) else {
            return false
        }

        var occupiedSegments: [Range<Int>] = []
        for (dayIndex, weekday) in Self.weekdayKeys.enumerated() {
            guard let intervals = weeklyHours[weekday] else { return false }
            for interval in intervals {
                guard
                    let opens = interval.canonicalMinuteOfDay(interval.opensAt),
                    let closes = interval.canonicalMinuteOfDay(interval.closesAt),
                    opens != closes
                else {
                    return false
                }
                let start = dayIndex * Self.minutesPerDay + opens
                let end = dayIndex * Self.minutesPerDay
                    + closes
                    + (closes < opens ? Self.minutesPerDay : 0)
                if end <= Self.minutesPerWeek {
                    occupiedSegments.append(start..<end)
                } else {
                    occupiedSegments.append(start..<Self.minutesPerWeek)
                    occupiedSegments.append(0..<(end - Self.minutesPerWeek))
                }
            }
        }

        let sortedSegments = occupiedSegments.sorted {
            if $0.lowerBound == $1.lowerBound {
                return $0.upperBound < $1.upperBound
            }
            return $0.lowerBound < $1.lowerBound
        }
        for (previous, current) in zip(sortedSegments, sortedSegments.dropFirst())
            where current.lowerBound < previous.upperBound {
            return false
        }
        return true
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

fileprivate extension ClinicHoursInterval {
    var continuesIntoFollowingDay: Bool {
        guard
            let opens = canonicalMinuteOfDay(opensAt),
            let closes = canonicalMinuteOfDay(closesAt)
        else {
            return false
        }
        return closes < opens
    }

    func dateRange(
        relativeTo startOfDay: Date,
        calendar: Calendar
    ) -> Range<Date>? {
        guard
            let opens = canonicalMinuteOfDay(opensAt),
            let closes = canonicalMinuteOfDay(closesAt),
            opens != closes,
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
        if closes < opens {
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

    func canonicalMinuteOfDay(_ value: String) -> Int? {
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
        let hour = Int(bytes[0] - 48) * 10 + Int(bytes[1] - 48)
        let minute = Int(bytes[3] - 48) * 10 + Int(bytes[4] - 48)
        guard
            (0...23).contains(hour),
            (0...59).contains(minute)
        else {
            return nil
        }
        return hour * 60 + minute
    }
}
