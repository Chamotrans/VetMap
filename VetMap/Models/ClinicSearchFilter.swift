import Foundation

struct ClinicSearchFilter: Equatable {
    enum Region: String, CaseIterable, Identifiable {
        case all = "全部地區"
        case taipei = "台北"
        case hongKong = "香港"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "地區"
            case .taipei:
                return "台北"
            case .hongKong:
                return "香港"
            }
        }

        fileprivate var keywords: [String] {
            switch self {
            case .all:
                return []
            case .taipei:
                return ["台北", "臺北"]
            case .hongKong:
                return ["香港"]
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

    var query = ""
    var region: Region = .all
    var price: Price = .all
    var verifiedOnly = false

    var isActive: Bool {
        !trimmedQuery.isEmpty || region != .all || price != .all || verifiedOnly
    }

    var activeDescription: String {
        var parts: [String] = []

        if !trimmedQuery.isEmpty {
            parts.append("「\(trimmedQuery)」")
        }

        if region != .all {
            parts.append(region.rawValue)
        }

        if price != .all {
            parts.append(price.rawValue)
        }

        if verifiedOnly {
            parts.append("已審核")
        }

        return parts.isEmpty ? "全部診所" : parts.joined(separator: "・")
    }

    func results(from clinics: [VetClinic]) -> [VetClinic] {
        clinics
            .filter(matches)
            .sorted(by: Self.sortClinics)
    }

    func matches(_ clinic: VetClinic) -> Bool {
        matchesQuery(clinic)
            && matchesRegion(clinic)
            && matchesPrice(clinic)
            && (!verifiedOnly || clinic.verified)
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
        let keywords = region.keywords
        guard !keywords.isEmpty else { return true }

        return keywords.contains { keyword in
            clinic.address.localizedCaseInsensitiveContains(keyword)
                || clinic.name.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func matchesPrice(_ clinic: VetClinic) -> Bool {
        switch price {
        case .all:
            return true
        case .budget:
            return clinic.priceLevel <= 1
        case .moderate:
            return clinic.priceLevel <= 2
        case .premium:
            return clinic.priceLevel >= 3
        }
    }

    private static func sortClinics(_ lhs: VetClinic, _ rhs: VetClinic) -> Bool {
        if lhs.verified != rhs.verified {
            return lhs.verified && !rhs.verified
        }

        if lhs.avgRating != rhs.avgRating {
            return lhs.avgRating > rhs.avgRating
        }

        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
