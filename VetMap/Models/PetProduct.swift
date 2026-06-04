import Foundation

struct PetProduct: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var description: String
    var category: String
    var price: Decimal
    var currency: String
    var clinicId: String?
    var affiliateURL: URL?
    var imageURL: URL?
    var tags: [String]
    var createdAt: Date
}
