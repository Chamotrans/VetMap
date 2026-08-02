import Foundation

enum ClinicDuplicateMatchReason: Equatable {
    case samePhoneAndName
    case samePhoneNearby(distanceMeters: Double)
    case sameNameAndAddress
    case sameNameNearby(distanceMeters: Double)
}

struct ClinicDuplicateMatch: Equatable {
    let clinic: VetClinic
    let reason: ClinicDuplicateMatchReason
}

enum ClinicDuplicateSubmissionDecision: Equatable {
    case submit
    case requiresConfirmation(ClinicDuplicateMatch)
    case alreadySubmitted
}

enum ClinicDuplicateMatcher {
    static func firstStrongMatch(
        for draft: VetClinic,
        in clinics: [VetClinic]
    ) -> ClinicDuplicateMatch? {
        for clinic in clinics {
            if let reason = strongMatchReason(between: draft, and: clinic) {
                return ClinicDuplicateMatch(clinic: clinic, reason: reason)
            }
        }
        return nil
    }

    static func strongMatchReason(
        between lhs: VetClinic,
        and rhs: VetClinic
    ) -> ClinicDuplicateMatchReason? {
        let lhsPhones = canonicalPhones(lhs.phone)
        let rhsPhones = canonicalPhones(rhs.phone)
        let samePhone = !lhsPhones.isEmpty && !lhsPhones.isDisjoint(with: rhsPhones)

        let lhsName = normalizedText(lhs.name)
        let rhsName = normalizedText(rhs.name)
        let sameName = lhsName != nil && lhsName == rhsName

        let lhsAddress = normalizedText(lhs.address)
        let rhsAddress = normalizedText(rhs.address)
        let sameAddress = lhsAddress != nil && lhsAddress == rhsAddress

        if samePhone, sameName {
            return .samePhoneAndName
        }

        let distance = distanceMeters(from: lhs.coordinate, to: rhs.coordinate)
        if samePhone, let distance, distance <= 200 {
            return .samePhoneNearby(distanceMeters: distance)
        }
        if sameName, sameAddress {
            return .sameNameAndAddress
        }
        if sameName, let distance, distance <= 100 {
            return .sameNameNearby(distanceMeters: distance)
        }
        return nil
    }

    static func canonicalPhones(_ value: String) -> Set<String> {
        let compatibility = value.precomposedStringWithCompatibilityMapping
        let segments = compatibility.split(separator: "/", omittingEmptySubsequences: false)
        if segments.count > 1 {
            let segmentPhones = segments.compactMap { canonicalPhoneDigits(String($0)) }
            if segmentPhones.count == segments.count {
                return Set(segmentPhones)
            }
        }

        guard let combined = canonicalPhoneDigits(compatibility) else { return [] }
        return [combined]
    }

    static func duplicateCandidates(
        from clinics: [VetClinic],
        excludingRemovedClinicIDs removedClinicIDs: Set<String>
    ) -> [VetClinic] {
        clinics.filter { !removedClinicIDs.contains($0.id) }
    }

    private static func canonicalPhoneDigits(_ value: String) -> String? {
        var digits = value.unicodeScalars
            .filter { CharacterSet.decimalDigits.contains($0) }
            .map(String.init)
            .joined()

        if digits.hasPrefix("00852"), digits.count == 13 {
            digits.removeFirst(5)
        } else if digits.hasPrefix("852"), digits.count == 11 {
            digits.removeFirst(3)
        }
        return digits.count == 8 ? digits : nil
    }

    static func normalizedText(_ value: String) -> String? {
        let normalized = value
            .precomposedStringWithCompatibilityMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
        let compact = normalized.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
        return compact.isEmpty ? nil : compact
    }

    static func distanceMeters(
        from lhs: ClinicCoordinate?,
        to rhs: ClinicCoordinate?
    ) -> Double? {
        guard
            let lhs,
            let rhs,
            lhs.latitude.isFinite,
            lhs.longitude.isFinite,
            rhs.latitude.isFinite,
            rhs.longitude.isFinite,
            (-90...90).contains(lhs.latitude),
            (-180...180).contains(lhs.longitude),
            (-90...90).contains(rhs.latitude),
            (-180...180).contains(rhs.longitude)
        else {
            return nil
        }

        let latitude1 = lhs.latitude * .pi / 180
        let latitude2 = rhs.latitude * .pi / 180
        let latitudeDelta = (rhs.latitude - lhs.latitude) * .pi / 180
        let longitudeDelta = (rhs.longitude - lhs.longitude) * .pi / 180
        let haversine = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let angularDistance = 2 * atan2(sqrt(haversine), sqrt(max(0, 1 - haversine)))
        return 6_371_000 * angularDistance
    }

    fileprivate static func fingerprint(for clinic: VetClinic) -> String {
        let coordinate = clinic.coordinate.map {
            String(format: "%.6f,%.6f", $0.latitude, $0.longitude)
        } ?? ""
        return [
            normalizedText(clinic.name) ?? "",
            normalizedText(clinic.address) ?? "",
            canonicalPhones(clinic.phone).sorted().joined(separator: ","),
            coordinate
        ].joined(separator: "|")
    }
}

struct ClinicDuplicateSubmissionGate {
    private var confirmedFingerprint: String?
    private var inFlightFingerprint: String?
    private var submittedFingerprint: String?

    func decision(
        for draft: VetClinic,
        existingClinics: [VetClinic]
    ) -> ClinicDuplicateSubmissionDecision {
        let fingerprint = ClinicDuplicateMatcher.fingerprint(for: draft)
        if submittedFingerprint == fingerprint || inFlightFingerprint == fingerprint {
            return .alreadySubmitted
        }
        if confirmedFingerprint == fingerprint {
            return .submit
        }
        if let match = ClinicDuplicateMatcher.firstStrongMatch(
            for: draft,
            in: existingClinics
        ) {
            return .requiresConfirmation(match)
        }
        return .submit
    }

    mutating func confirmDifferentClinic(_ draft: VetClinic) {
        confirmedFingerprint = ClinicDuplicateMatcher.fingerprint(for: draft)
    }

    mutating func beginSubmission(_ draft: VetClinic) -> Bool {
        let fingerprint = ClinicDuplicateMatcher.fingerprint(for: draft)
        guard
            inFlightFingerprint != fingerprint,
            submittedFingerprint != fingerprint
        else {
            return false
        }
        inFlightFingerprint = fingerprint
        return true
    }

    mutating func finishSubmission(_ draft: VetClinic, succeeded: Bool) {
        let fingerprint = ClinicDuplicateMatcher.fingerprint(for: draft)
        guard inFlightFingerprint == fingerprint else { return }
        inFlightFingerprint = nil
        if succeeded {
            submittedFingerprint = fingerprint
        }
    }
}
