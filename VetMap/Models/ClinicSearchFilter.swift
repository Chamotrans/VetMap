import Foundation

struct ClinicSearchFilter: Equatable {
    enum Region: String, CaseIterable, Identifiable {
        case all = "全部地區"
        case hongKong = "香港"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "地區"
            case .hongKong:
                return "香港"
            }
        }
    }

    enum Price: String, CaseIterable, Identifiable {
        case all = "全部價格"
        case budget = "$"
        case moderate = "$$ 以下"
        case premium = "$$$"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "價格"
            case .budget:
                return "$"
            case .moderate:
                return "$$ 以下"
            case .premium:
                return "$$$"
            }
        }
    }

    enum Availability: String, CaseIterable, Identifiable {
        case all = "全部營業狀態"
        case openNow = "營業中"
        case open24Hours = "24 小時"
        case nightService = "夜診"

        var id: String { rawValue }

        var title: String {
            self == .all ? "營業狀態" : rawValue
        }

        var limitationMessage: String? {
            switch self {
            case .all:
                return nil
            case .openNow, .open24Hours, .nightService:
                return "只按有現行官方營業資料的診所篩選；未列出的診所不代表休息，出發前請先致電。"
            }
        }
    }

    var query = ""
    var availability: Availability = .all
    var region: Region = .all
    var price: Price = .all

    var isActive: Bool {
        !trimmedQuery.isEmpty
            || availability != .all
            || region != .all
            || price != .all
    }

    var activeDescription: String {
        var parts: [String] = []

        if !trimmedQuery.isEmpty {
            parts.append("「\(trimmedQuery)」")
        }

        if region != .all {
            parts.append(region.rawValue)
        }

        if availability != .all {
            parts.append(availability.rawValue)
        }

        if price != .all {
            parts.append(price.rawValue)
        }

        return parts.isEmpty ? "全部診所" : parts.joined(separator: "・")
    }

    func results(
        from clinics: [VetClinic],
        at date: Date = Date()
    ) -> [VetClinic] {
        clinics
            .filter { matches($0, at: date) }
            .sorted { sortClinics($0, $1, at: date) }
    }

    func matches(_ clinic: VetClinic, at date: Date = Date()) -> Bool {
        matchesQuery(clinic)
            && matchesAvailability(clinic, at: date)
            && matchesRegion(clinic)
            && matchesPrice(clinic)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var queryTokens: [String] {
        trimmedQuery
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    private func matchesQuery(_ clinic: VetClinic) -> Bool {
        let tokens = queryTokens
        guard !tokens.isEmpty else { return true }

        let haystack = ([
            clinic.name,
            clinic.address,
            clinic.phone
        ] + clinic.services + clinic.tags)
            .joined(separator: " ")

        return tokens.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    private func matchesRegion(_ clinic: VetClinic) -> Bool {
        switch region {
        case .all:
            return true
        case .hongKong:
            if clinic.catalogRegion?.caseInsensitiveCompare("HK") == .orderedSame {
                return true
            }
            guard let coordinate = clinic.coordinate else { return false }
            return (22.1...22.6).contains(coordinate.latitude)
                && (113.8...114.5).contains(coordinate.longitude)
        }
    }

    private func matchesAvailability(_ clinic: VetClinic, at date: Date) -> Bool {
        switch availability {
        case .all:
            return true
        case .openNow:
            return clinic.isOpen(at: date)
        case .open24Hours:
            guard clinic.availability?.isCurrent(at: date) == true else {
                return false
            }
            return clinic.availability?.is24Hours == true
        case .nightService:
            return clinic.hasCurrentNightService(at: date)
        }
    }

    private func matchesPrice(_ clinic: VetClinic) -> Bool {
        switch price {
        case .all:
            return true
        case .budget:
            return clinic.priceLevel == 1
        case .moderate:
            return (1...2).contains(clinic.priceLevel)
        case .premium:
            return clinic.priceLevel >= 3
        }
    }

    private func sortClinics(
        _ lhs: VetClinic,
        _ rhs: VetClinic,
        at date: Date
    ) -> Bool {
        let lhsRank = lhs.availabilitySortRank(at: date)
        let rhsRank = rhs.availabilitySortRank(at: date)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
