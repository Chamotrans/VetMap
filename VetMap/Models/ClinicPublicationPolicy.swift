import Foundation

/// Converts a moderated clinic submission into the narrow public record that
/// approval is allowed to create. Approval confirms suitability for listing;
/// it does not verify user-supplied operating or reputation claims.
enum ClinicPublicationPolicy {
    static func safeProjection(
        of submittedClinic: VetClinic,
        submitterID: String
    ) -> VetClinic? {
        guard submittedClinic.hasReliableHongKongCoordinate else { return nil }

        return VetClinic(
            id: submittedClinic.id,
            name: submittedClinic.name,
            address: submittedClinic.address,
            coordinate: submittedClinic.coordinate,
            catalogRegion: "HK",
            phone: submittedClinic.phone,
            website: submittedClinic.website,
            openingHours: [:],
            availability: nil,
            services: [],
            avgRating: 0,
            reviewCount: 0,
            priceLevel: 0,
            images: [],
            tags: [],
            createdAt: submittedClinic.createdAt,
            updatedAt: submittedClinic.updatedAt,
            reportedBy: submitterID,
            verified: false
        )
    }
}
