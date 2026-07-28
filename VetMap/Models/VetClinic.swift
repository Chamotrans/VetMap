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
}
