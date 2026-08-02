import Foundation

@main
struct ClinicPublicationPolicyHarness {
    static func main() {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            passed += 1
        }

        let createdAt = Date(timeIntervalSince1970: 1_775_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_775_000_100)
        let coordinate = ClinicCoordinate(latitude: 22.3193, longitude: 114.1694)
        let website = URL(string: "https://example.hk/clinic")!
        let submitted = clinic(
            coordinate: coordinate,
            catalogRegion: "TW",
            website: website,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        guard let projected = ClinicPublicationPolicy.safeProjection(
            of: submitted,
            submitterID: "firebase-user-1"
        ) else {
            preconditionFailure("valid Hong Kong clinic must project")
        }

        check(projected.id == submitted.id, "identity id retained")
        check(projected.name == submitted.name, "identity name retained")
        check(projected.address == submitted.address, "identity address retained")
        check(projected.coordinate == coordinate, "reliable coordinate retained")
        check(projected.phone == submitted.phone, "phone retained")
        check(projected.website == website, "website retained")
        check(projected.createdAt == createdAt, "created timestamp retained")
        check(projected.updatedAt == updatedAt, "updated timestamp retained")
        check(projected.reportedBy == "firebase-user-1", "submitter canonicalized")
        check(projected.catalogRegion == "HK", "catalog region forced")
        check(!projected.verified, "verification claim cleared")
        check(projected.openingHours.isEmpty, "opening hours cleared")
        check(projected.availability == nil, "verified availability cleared")
        check(projected.services.isEmpty, "services cleared")
        check(projected.avgRating == 0, "average rating cleared")
        check(projected.reviewCount == 0, "review count cleared")
        check(projected.priceLevel == 0, "price level cleared")
        check(projected.images.isEmpty, "images cleared")
        check(projected.tags.isEmpty, "tags cleared")

        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: nil),
                submitterID: "firebase-user-1"
            ) == nil,
            "missing coordinate fails closed"
        )
        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: ClinicCoordinate(latitude: .nan, longitude: 114.1)),
                submitterID: "firebase-user-1"
            ) == nil,
            "non-finite latitude fails closed"
        )
        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: ClinicCoordinate(latitude: 22.3, longitude: .infinity)),
                submitterID: "firebase-user-1"
            ) == nil,
            "non-finite longitude fails closed"
        )
        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: ClinicCoordinate(latitude: 25.033, longitude: 121.5654)),
                submitterID: "firebase-user-1"
            ) == nil,
            "non-Hong-Kong coordinate fails closed"
        )
        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: ClinicCoordinate(latitude: 22.7, longitude: 114.2)),
                submitterID: "firebase-user-1"
            ) == nil,
            "latitude outside Hong Kong boundary fails closed"
        )
        check(
            ClinicPublicationPolicy.safeProjection(
                of: clinic(coordinate: ClinicCoordinate(latitude: 22.3, longitude: 113.7)),
                submitterID: "firebase-user-1"
            ) == nil,
            "longitude outside Hong Kong boundary fails closed"
        )

        print("{\"clinicPublicationPolicy\":true,\"passed\":\(passed)}")
    }

    private static func clinic(
        coordinate: ClinicCoordinate?,
        catalogRegion: String? = nil,
        website: URL? = nil,
        createdAt: Date = .distantPast,
        updatedAt: Date = .distantPast
    ) -> VetClinic {
        VetClinic(
            id: "submitted-clinic",
            name: "香港社群投稿診所",
            address: "香港測試地址",
            coordinate: coordinate,
            catalogRegion: catalogRegion,
            phone: "2123 4567",
            website: website,
            openingHours: ["mon": "24 小時"],
            availability: ClinicAvailability(
                schemaVersion: 1,
                migrationId: "untrusted-claim",
                timeZoneIdentifier: "Asia/Hong_Kong",
                weeklyHours: [:],
                is24Hours: true,
                offersNightService: true,
                displayLabel: "24 小時",
                serviceNote: "用戶聲稱",
                sourceURL: URL(string: "https://example.hk/claim")!,
                sourceName: "用戶聲稱",
                verifiedAt: Date(),
                expiresAt: Date(timeIntervalSinceNow: 86_400)
            ),
            services: ["24 小時急症", "夜診"],
            avgRating: 5,
            reviewCount: 999,
            priceLevel: 3,
            images: [URL(string: "https://example.hk/untrusted.jpg")!],
            tags: ["官方", "已驗證"],
            createdAt: createdAt,
            updatedAt: updatedAt,
            reportedBy: "spoofed-user",
            verified: true
        )
    }
}
