import Foundation

/// Release builds intentionally contain no bundled merchant catalog.
///
/// Merchant names and commercial listings may only return after a rights
/// packet confirms the source, permitted fields, commercial reuse, required
/// attribution, and expiry terms. The consumer catalog is also gated by
/// `FeatureFlags.catalogEnabled`.
struct MockProductRepository {
    #if DEBUG
    static let seedProducts: [PetProduct] = [
        PetProduct(
            id: "debug-product",
            name: "VetMap 測試用品",
            description: "只供本機預覽及測試",
            category: "用品",
            price: Decimal(0),
            currency: "HKD",
            clinicId: nil,
            affiliateURL: nil,
            imageURL: nil,
            tags: ["測試資料"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000)
        )
    ]
    #else
    static let seedProducts: [PetProduct] = []
    #endif
}
