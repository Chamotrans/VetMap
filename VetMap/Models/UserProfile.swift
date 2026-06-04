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
