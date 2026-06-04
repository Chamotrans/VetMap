import Foundation

struct VetClinic: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var address: String
    var coordinate: ClinicCoordinate
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
