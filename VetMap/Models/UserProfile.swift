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

enum SavedCatalogItemKind: String, Equatable {
    case service
    case insurance
}

/// Canonical IDs stored in `users/{uid}.savedProducts`. The legacy field name
/// is retained for Firestore compatibility even though the current Hong Kong
/// catalog contains both pet services and official insurance-directory links.
enum SavedCatalogItems {
    static let storageKey = "savedCatalogItemsCacheV1"
    static let cacheOwnerKey = "savedCatalogItemsCacheUserID"
    static let maximumCount = 200
    static let allowedItemIDs: [String] = {
        let supplyNumbers = Array(1...12)
            + [17]
            + Array(19...33)
            + Array(41...62)
        let groomingNumbers = Array(1...28) + Array(35...56)
        let funeralNumbers = Array(1...24)
        return serviceIDs(prefix: "sup", numbers: supplyNumbers)
            + serviceIDs(prefix: "grm", numbers: groomingNumbers)
            + serviceIDs(prefix: "fun", numbers: funeralNumbers)
            + [
                "insurance-hk-fwd",
                "insurance-hk-onedegree",
                "insurance-hk-bluecross"
            ]
    }()

    private static let allowedItemIDSet = Set(allowedItemIDs)

    static func kind(for itemID: String) -> SavedCatalogItemKind? {
        let value = itemID
        guard allowedItemIDSet.contains(value) else { return nil }
        if fullMatch(value, pattern: "^hk-service-[a-z]{3}-[0-9]{3}$") {
            return .service
        }
        if fullMatch(value, pattern: "^insurance-hk-[a-z0-9][a-z0-9-]{0,80}$") {
            return .insurance
        }
        return nil
    }

    static func isValidItemID(_ value: String) -> Bool {
        value.count <= 200 && kind(for: value) != nil
    }

    /// Legacy strings remain visible as unavailable saved items so users can
    /// remove them explicitly. Only current allowlisted IDs may be added.
    static func isSafeStoredItemID(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.count <= 200
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    static func isCurrentSession(
        expectedUserID: String,
        activeUserID: String?,
        expectedGeneration: Int,
        currentGeneration: Int
    ) -> Bool {
        !expectedUserID.isEmpty
            && activeUserID == expectedUserID
            && expectedGeneration == currentGeneration
    }

    static func normalized(_ itemIDs: [String]) -> [String] {
        normalized(
            itemIDs,
            transform: { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            validator: isValidItemID
        )
    }

    static func normalizedStored(_ itemIDs: [String]) -> [String] {
        // Preserve legacy values byte-for-byte so Firestore arrayRemove can
        // delete the exact stored value instead of a trimmed lookalike.
        normalized(itemIDs, transform: { $0 }, validator: isSafeStoredItemID)
    }

    private static func normalized(
        _ itemIDs: [String],
        transform: (String) -> String,
        validator: (String) -> Bool
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawID in itemIDs {
            let itemID = transform(rawID)
            guard validator(itemID), seen.insert(itemID).inserted else {
                continue
            }
            result.append(itemID)
            if result.count == maximumCount { break }
        }
        return result
    }

    static func decode(_ storedValue: String) -> [String] {
        guard let data = storedValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return normalizedStored(decoded)
    }

    static func encode(_ itemIDs: [String]) -> String {
        guard let data = try? JSONEncoder().encode(normalizedStored(itemIDs)),
              let value = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return value
    }

    static func setting(
        _ itemID: String,
        isSaved: Bool,
        in itemIDs: [String]
    ) -> [String] {
        var result = normalizedStored(itemIDs)
        let normalizedID = isSaved
            ? itemID.trimmingCharacters(in: .whitespacesAndNewlines)
            : itemID

        if isSaved {
            guard isValidItemID(normalizedID) else { return result }
            guard !result.contains(normalizedID), result.count < maximumCount else {
                return result
            }
            result.append(normalizedID)
        } else {
            guard isSafeStoredItemID(normalizedID) else { return result }
            result.removeAll { $0 == normalizedID }
        }
        return result
    }

    static func rollingBack(
        _ itemID: String,
        attemptedSave: Bool,
        previousItemIDs: [String],
        currentItemIDs: [String]
    ) -> [String] {
        if attemptedSave {
            return setting(itemID, isSaved: false, in: currentItemIDs)
        }

        var result = normalizedStored(currentItemIDs)
        let previous = normalizedStored(previousItemIDs)
        guard isSafeStoredItemID(itemID),
              previous.contains(itemID),
              !result.contains(itemID),
              result.count < maximumCount else {
            return result
        }
        let originalIndex = previous.firstIndex(of: itemID) ?? result.endIndex
        result.insert(itemID, at: min(originalIndex, result.endIndex))
        return result
    }

    private static func fullMatch(_ value: String, pattern: String) -> Bool {
        guard let match = value.range(of: pattern, options: .regularExpression) else {
            return false
        }
        return match == value.startIndex..<value.endIndex
    }

    private static func serviceIDs(prefix: String, numbers: [Int]) -> [String] {
        numbers.map { number in
            "hk-service-\(prefix)-\(String(format: "%03d", number))"
        }
    }
}
