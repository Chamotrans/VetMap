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

/// A licence entry published by Taiwan's Ministry of Agriculture.
///
/// These records intentionally remain separate from `VetClinic`: the official
/// dataset contains an address but no coordinate, rating, opening hours or
/// service claims. Keeping a separate model prevents the app from inventing
/// map coordinates or presenting government registration data as community
/// verification.
struct OfficialClinicRecord: Identifiable, Codable, Equatable {
    let id: String
    let city: String
    let licenseNumber: String
    let licenseType: String
    let licenseStatus: String
    let institutionName: String
    let phone: String
    let issueDate: String
    let address: String
}

struct OfficialClinicCatalogManifest: Codable, Equatable {
    let kind: String
    let datasetId: String
    let sourceName: String
    let sourceURL: String
    let licenseName: String
    let licenseURL: String
    let snapshotDate: String
    let recordCount: Int
    let shardCount: Int
    let updatedAt: Date
    let status: String
}

struct OfficialClinicCatalogShard: Codable, Equatable {
    let kind: String
    let datasetId: String
    let snapshotDate: String
    let index: Int
    let records: [OfficialClinicRecord]
}

struct OfficialClinicCatalog: Equatable {
    let manifest: OfficialClinicCatalogManifest
    let records: [OfficialClinicRecord]
}
