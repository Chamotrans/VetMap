import Foundation

struct Review: Identifiable, Codable, Equatable {
    let id: String
    var clinicId: String
    var userId: String
    var userName: String
    var rating: Int
    var title: String
    var content: String
    var treatmentType: String?
    var cost: Decimal?
    var images: [URL]?
    var createdAt: Date
    var updatedAt: Date
    var helpfulCount: Int
}
