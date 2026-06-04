import Foundation

struct Insurance: Identifiable, Codable, Equatable {
    let id: String
    var providerName: String
    var planName: String
    var description: String
    var monthlyPremium: Decimal
    var annualPremium: Decimal
    var coverage: [String]
    var exclusions: [String]
    var website: URL
    var contactPhone: String
}
