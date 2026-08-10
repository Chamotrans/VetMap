import Foundation

struct Quote: Identifiable, Codable, Equatable {
    let id: String
    var clinicId: String
    var userId: String
    var treatmentType: String
    var estimatedCost: Decimal
    var actualCost: Decimal?
    var currency: String
    var notes: String
    var createdAt: Date
}

struct QuoteDraft: Equatable {
    var treatmentType: String
    var estimatedCost: Decimal
    var actualCost: Decimal?
    var currency: String
    var notes: String
}
