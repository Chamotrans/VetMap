import Foundation

@main
struct ClinicDuplicateMatcherHarness {
    static func main() {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            passed += 1
        }

        check(
            ClinicDuplicateMatcher.canonicalPhones("＋８５２　２１２３－４５６７") == ["21234567"],
            "fullwidth +852 phone"
        )
        check(
            ClinicDuplicateMatcher.canonicalPhones("00852 2123 4567") == ["21234567"],
            "00852 phone"
        )
        check(
            ClinicDuplicateMatcher.canonicalPhones("2123/4567") == ["21234567"],
            "four-plus-four slash remains one phone"
        )
        check(
            ClinicDuplicateMatcher.canonicalPhones("2698 2185 / 2687 0226")
                == ["26982185", "26870226"],
            "two spaced landlines"
        )
        check(
            ClinicDuplicateMatcher.canonicalPhones("2653 3632 / 6168 6175")
                == ["26533632", "61686175"],
            "landline and mobile"
        )
        check(
            ClinicDuplicateMatcher.canonicalPhones("28828123/62158608")
                == ["28828123", "62158608"],
            "two compact phones"
        )
        check(ClinicDuplicateMatcher.canonicalPhones("123").isEmpty, "insufficient phone")
        check(
            ClinicDuplicateMatcher.normalizedText(" ＨＡＰＰＹ－Pet！診所 ") == "happypet診所",
            "name normalization"
        )
        check(
            ClinicDuplicateMatcher.normalizedText("香港．中環，皇后大道中 １ 號")
                == "香港中環皇后大道中1號",
            "address normalization"
        )

        let origin = ClinicCoordinate(latitude: 22.3000, longitude: 114.2000)
        let within100 = ClinicCoordinate(latitude: 22.3005, longitude: 114.2000)
        let within200 = ClinicCoordinate(latitude: 22.3015, longitude: 114.2000)
        let beyond200 = ClinicCoordinate(latitude: 22.3030, longitude: 114.2000)
        check(
            (ClinicDuplicateMatcher.distanceMeters(from: origin, to: within100) ?? .infinity) < 100,
            "distance under 100m"
        )
        check(
            (ClinicDuplicateMatcher.distanceMeters(from: origin, to: within200) ?? .infinity) < 200,
            "distance under 200m"
        )
        check(
            (ClinicDuplicateMatcher.distanceMeters(from: origin, to: beyond200) ?? 0) > 200,
            "distance over 200m"
        )
        check(
            ClinicDuplicateMatcher.distanceMeters(from: nil, to: within100) == nil,
            "missing distance"
        )

        let draft = clinic(
            id: "draft",
            name: "Happy Pet 診所",
            address: "香港中環皇后大道中1號",
            phone: "+852 2123 4567",
            coordinate: origin
        )
        let phoneAndName = clinic(
            id: "phone-name",
            name: "ＨＡＰＰＹ－ＰＥＴ 診所！",
            address: "九龍遠處",
            phone: "２１２３－４５６７",
            coordinate: beyond200
        )
        check(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: phoneAndName)
                == .samePhoneAndName,
            "same phone and normalized name"
        )

        let phoneNearby = clinic(
            id: "phone-nearby",
            name: "另一間獸醫",
            address: "另一地址",
            phone: "2123 4567",
            coordinate: within200
        )
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: draft,
            and: phoneNearby
        ) else {
            preconditionFailure("same phone within 200m")
        }
        passed += 1

        let nameAndAddress = clinic(
            id: "name-address",
            name: "happy—pet 診所",
            address: "香港中環；皇后大道中１號",
            phone: "",
            coordinate: beyond200
        )
        check(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: nameAndAddress)
                == .sameNameAndAddress,
            "same normalized name and address"
        )

        let nameNearby = clinic(
            id: "name-nearby",
            name: "HAPPY PET 診所",
            address: "不同地址",
            phone: "8765 4321",
            coordinate: within100
        )
        guard case .sameNameNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: draft,
            and: nameNearby
        ) else {
            preconditionFailure("same name within 100m")
        }
        passed += 1

        let phoneFar = clinic(
            id: "phone-far",
            name: "不同名稱",
            address: "不同地址",
            phone: "21234567",
            coordinate: beyond200
        )
        check(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: phoneFar) == nil,
            "phone alone beyond 200m"
        )

        let multiPhoneDraft = clinic(
            id: "multi-phone-draft",
            name: "多電話診所",
            address: "香港中環測試地址",
            phone: "2698 2185 / 2687 0226",
            coordinate: origin
        )
        let firstPhoneNearby = clinic(
            id: "first-phone",
            name: "另一名稱一",
            address: "另一地址一",
            phone: "2698 2185",
            coordinate: within200
        )
        let secondPhoneNearby = clinic(
            id: "second-phone",
            name: "另一名稱二",
            address: "另一地址二",
            phone: "2687 0226",
            coordinate: within200
        )
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: multiPhoneDraft,
            and: firstPhoneNearby
        ) else {
            preconditionFailure("first canonical phone must match")
        }
        passed += 1
        guard case .samePhoneNearby = ClinicDuplicateMatcher.strongMatchReason(
            between: multiPhoneDraft,
            and: secondPhoneNearby
        ) else {
            preconditionFailure("second canonical phone must match")
        }
        passed += 1

        let nameFar = clinic(
            id: "name-far",
            name: "Happy Pet 診所",
            address: "不同地址",
            phone: "87654321",
            coordinate: beyond200
        )
        check(
            ClinicDuplicateMatcher.strongMatchReason(between: draft, and: nameFar) == nil,
            "name alone branch must not match"
        )
        check(
            ClinicDuplicateMatcher.firstStrongMatch(for: draft, in: [nameFar, phoneFar]) == nil,
            "indirect chain must not match"
        )
        let insufficientDraft = clinic(
            id: "insufficient",
            name: "只得名稱",
            address: "",
            phone: "",
            coordinate: nil
        )
        let insufficientExisting = clinic(
            id: "insufficient-existing",
            name: "只得名稱",
            address: "",
            phone: "",
            coordinate: nil
        )
        check(
            ClinicDuplicateMatcher.firstStrongMatch(
                for: insufficientDraft,
                in: [insufficientExisting]
            ) == nil,
            "insufficient fields fail open"
        )
        check(
            ClinicDuplicateMatcher.duplicateCandidates(
                from: [draft, phoneAndName, phoneNearby],
                excludingRemovedClinicIDs: [phoneAndName.id]
            ).map(\.id) == [draft.id, phoneNearby.id],
            "removed clinics excluded without applying display filters"
        )

        var gate = ClinicDuplicateSubmissionGate()
        guard case let .requiresConfirmation(match) = gate.decision(
            for: draft,
            existingClinics: [phoneAndName]
        ) else {
            preconditionFailure("first duplicate must require confirmation")
        }
        check(match.clinic.id == phoneAndName.id, "confirmation candidate")
        gate.confirmDifferentClinic(draft)
        check(
            gate.decision(for: draft, existingClinics: [phoneAndName]) == .submit,
            "confirmed draft submits"
        )
        check(gate.beginSubmission(draft), "first submission begins")
        check(!gate.beginSubmission(draft), "in-flight submission is one shot")
        check(
            gate.decision(for: draft, existingClinics: [phoneAndName]) == .alreadySubmitted,
            "in-flight decision blocks duplicate"
        )
        gate.finishSubmission(draft, succeeded: false)
        check(
            gate.decision(for: draft, existingClinics: [phoneAndName]) == .submit,
            "failed confirmed submission may retry without prompting"
        )
        check(gate.beginSubmission(draft), "retry begins once")
        gate.finishSubmission(draft, succeeded: true)
        check(
            gate.decision(for: draft, existingClinics: [phoneAndName]) == .alreadySubmitted,
            "successful draft cannot resubmit"
        )
        check(
            ClinicDuplicateSubmissionGate().decision(for: draft, existingClinics: []) == .submit,
            "no public candidates fail open"
        )

        var sortedFingerprintGate = ClinicDuplicateSubmissionGate()
        sortedFingerprintGate.confirmDifferentClinic(multiPhoneDraft)
        var reorderedPhoneDraft = multiPhoneDraft
        reorderedPhoneDraft.phone = "2687 0226 / 2698 2185"
        check(
            sortedFingerprintGate.decision(
                for: reorderedPhoneDraft,
                existingClinics: [firstPhoneNearby]
            ) == .submit,
            "phone-set fingerprint is order independent"
        )

        print("{\"clinicDuplicateMatcher\":true,\"passed\":\(passed)}")
    }

    private static func clinic(
        id: String,
        name: String,
        address: String,
        phone: String,
        coordinate: ClinicCoordinate?
    ) -> VetClinic {
        VetClinic(
            id: id,
            name: name,
            address: address,
            coordinate: coordinate,
            catalogRegion: "HK",
            phone: phone,
            website: nil,
            openingHours: [:],
            availability: nil,
            services: [],
            avgRating: 0,
            reviewCount: 0,
            priceLevel: 0,
            images: [],
            tags: [],
            createdAt: .distantPast,
            updatedAt: .distantPast,
            reportedBy: "harness",
            verified: false
        )
    }
}
