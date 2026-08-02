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

        let unrelated = clinic(
            id: "unrelated",
            name: "完全不同診所",
            address: "香港另一地址",
            phone: "99998888",
            coordinate: beyond200
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [unrelated],
                removedClinicIDs: []
            ) == .approve,
            "approval no-match proceeds"
        )
        guard case let .requiresOverride(initialApprovalMatch) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [phoneAndName],
                removedClinicIDs: []
            )
        else {
            preconditionFailure("approval strong match requires override")
        }
        check(
            initialApprovalMatch.matches.map(\.clinic.id) == [phoneAndName.id],
            "approval match candidate set"
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [phoneAndName],
                removedClinicIDs: [],
                overridingChallengeFingerprint:
                    initialApprovalMatch.fingerprint
            ) == .approve,
            "exact candidate-set override proceeds"
        )

        var sameIDContentChanged = phoneAndName
        sameIDContentChanged.address = "另一個正規化地址"
        guard case let .requiresOverride(contentChangedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [sameIDContentChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: initialApprovalMatch.fingerprint
            )
        else {
            preconditionFailure("same-ID normalized evidence change must reprompt")
        }
        check(
            contentChangedChallenge.matches.map(\.clinic.id) == [phoneAndName.id],
            "same-ID content change keeps candidate identity"
        )
        check(
            contentChangedChallenge.matches.first?.reason == .samePhoneAndName,
            "same-ID content change can retain match reason"
        )
        check(
            contentChangedChallenge.fingerprint != initialApprovalMatch.fingerprint,
            "same-ID normalized evidence changes challenge fingerprint"
        )

        var sameIDReasonChanged = sameIDContentChanged
        sameIDReasonChanged.name = "另一間獸醫"
        sameIDReasonChanged.coordinate = within200
        guard case let .requiresOverride(reasonChangedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [sameIDReasonChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: contentChangedChallenge.fingerprint
            )
        else {
            preconditionFailure("same-ID match reason change must reprompt")
        }
        check(
            reasonChangedChallenge.matches.map(\.clinic.id) == [phoneAndName.id],
            "same-ID reason change keeps candidate identity"
        )
        guard
            let reasonChangedMatch = reasonChangedChallenge.matches.first,
            case .samePhoneNearby = reasonChangedMatch.reason
        else {
            preconditionFailure("same-ID candidate should now match by nearby phone")
        }
        passed += 1
        check(
            reasonChangedChallenge.fingerprint != contentChangedChallenge.fingerprint,
            "same-ID reason and distance semantics change fingerprint"
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [sameIDReasonChanged],
                removedClinicIDs: [],
                overridingChallengeFingerprint: reasonChangedChallenge.fingerprint
            ) == .approve,
            "exact same-ID changed-evidence override proceeds"
        )

        guard case let .requiresOverride(wrongOverrideMatch) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [phoneAndName],
                removedClinicIDs: [],
                overridingChallengeFingerprint: "wrong-fingerprint"
            )
        else {
            preconditionFailure("wrong override must reprompt")
        }
        check(
            wrongOverrideMatch.matches.map(\.clinic.id) == [phoneAndName.id],
            "wrong override candidate set unchanged"
        )
        guard case let .requiresOverride(changedApprovalMatch) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [phoneNearby],
                removedClinicIDs: [],
                overridingChallengeFingerprint:
                    initialApprovalMatch.fingerprint
            )
        else {
            preconditionFailure("stale override must reprompt for changed candidate")
        }
        check(
            changedApprovalMatch.matches.map(\.clinic.id) == [phoneNearby.id],
            "changed candidate set reprompt"
        )

        let aCandidate = clinic(
            id: "a-candidate",
            name: draft.name,
            address: "不同地址 A",
            phone: draft.phone,
            coordinate: beyond200
        )
        let zCandidate = clinic(
            id: "z-candidate",
            name: "另一名稱 Z",
            address: "不同地址 Z",
            phone: draft.phone,
            coordinate: within200
        )
        guard case let .requiresOverride(oneCandidateChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [aCandidate],
                removedClinicIDs: []
            )
        else {
            preconditionFailure("one matching candidate must require override")
        }
        check(
            !oneCandidateChallenge.fingerprint.isEmpty,
            "one-candidate fingerprint binds normalized evidence"
        )
        guard case let .requiresOverride(expandedChallenge) =
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [zCandidate, aCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint:
                    oneCandidateChallenge.fingerprint
            )
        else {
            preconditionFailure("new later candidate must invalidate stale override")
        }
        check(
            expandedChallenge.matches.map(\.clinic.id) == [aCandidate.id, zCandidate.id],
            "expanded candidate set is complete and sorted"
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [zCandidate, aCandidate],
                removedClinicIDs: [],
                overridingChallengeFingerprint:
                    expandedChallenge.fingerprint
            ) == .approve,
            "exact expanded candidate-set override proceeds"
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [phoneAndName],
                removedClinicIDs: [phoneAndName.id]
            ) == .approve,
            "removed candidate is ignored"
        )
        check(
            ClinicDuplicateApprovalPolicy.decision(
                for: draft,
                approvedClinics: [nameFar, phoneFar],
                removedClinicIDs: []
            ) == .approve,
            "indirect duplicate chain does not block approval"
        )

        check(
            ClinicDuplicateMatchReason.samePhoneAndName.adminReadableLabel
                == "相同電話及名稱",
            "same phone and name admin label"
        )
        check(
            ClinicDuplicateMatchReason.samePhoneNearby(distanceMeters: 42.6)
                .adminReadableLabel == "相同電話，距離約 43 米",
            "same phone nearby admin label"
        )
        check(
            ClinicDuplicateMatchReason.sameNameAndAddress.adminReadableLabel
                == "相同名稱及地址",
            "same name and address admin label"
        )
        check(
            ClinicDuplicateMatchReason.sameNameNearby(distanceMeters: 12.4)
                .adminReadableLabel == "相同名稱，距離約 12 米",
            "same name nearby admin label"
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
