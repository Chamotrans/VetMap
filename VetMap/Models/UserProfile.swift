import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var email: String
    var photoURL: URL?
    var isPremium: Bool
    var premiumExpiry: Date?
    var favoriteClinics: [String]
    var savedProducts: [String]
    var createdAt: Date
}

/// Canonicalises the account-synchronised clinic favourites shared by the UI,
/// Firestore writer and release harness. Order is stable so the user's list
/// does not jump between launches; malformed, duplicate and unsafe IDs are
/// discarded before they reach local storage or the profile document.
enum ClinicFavorites {
    static let storageKey = "favorites"
    static let cacheOwnerKey = "favoritesCacheUserID"
    static let maximumCount = 200

    static func cloudMigrationKey(for userID: String) -> String {
        "favoritesCloudMigrationV1.\(userID)"
    }

    static func isValidClinicID(_ value: String) -> Bool {
        guard value.count <= 200 else { return false }
        guard let match = value.range(
            of: "^[A-Za-z0-9][A-Za-z0-9._-]*$",
            options: .regularExpression
        ) else {
            return false
        }
        return match == value.startIndex..<value.endIndex
    }

    static func normalized(_ clinicIDs: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawID in clinicIDs {
            let clinicID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidClinicID(clinicID), seen.insert(clinicID).inserted else {
                continue
            }
            result.append(clinicID)
            if result.count == maximumCount { break }
        }
        return result
    }

    static func decode(_ storedValue: String) -> [String] {
        guard let data = storedValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return normalized(decoded)
    }

    static func encode(_ clinicIDs: [String]) -> String {
        let normalizedIDs = normalized(clinicIDs)
        guard let data = try? JSONEncoder().encode(normalizedIDs),
              let value = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return value
    }

    static func setting(
        _ clinicID: String,
        isFavorite: Bool,
        in clinicIDs: [String]
    ) -> [String] {
        var result = normalized(clinicIDs)
        let normalizedID = clinicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidClinicID(normalizedID) else { return result }

        if isFavorite {
            guard !result.contains(normalizedID), result.count < maximumCount else {
                return result
            }
            result.append(normalizedID)
        } else {
            result.removeAll { $0 == normalizedID }
        }
        return result
    }
}
