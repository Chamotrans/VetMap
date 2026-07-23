import Foundation

/// Release builds intentionally contain no bundled insurance plans.
///
/// Insurance pricing and coverage are regulated, time-sensitive third-party
/// content. A plan may only return after the provider or an authoritative
/// licensed source supplies current terms and reuse permission. The consumer
/// catalog is also gated by `FeatureFlags.catalogEnabled`.
struct MockInsuranceRepository {
    #if DEBUG
    static let seedPlans: [Insurance] = [
        Insurance(
            id: "debug-insurance",
            providerName: "VetMap 測試供應商",
            planName: "預覽方案",
            description: "只供本機預覽及測試，並非真實保險產品。",
            monthlyPremium: Decimal(0),
            annualPremium: Decimal(0),
            coverage: ["測試保障項目"],
            exclusions: ["不適用於任何真實投保用途"],
            website: URL(string: "https://vetmap-app.web.app")!,
            contactPhone: ""
        )
    ]
    #else
    static let seedPlans: [Insurance] = []
    #endif
}
