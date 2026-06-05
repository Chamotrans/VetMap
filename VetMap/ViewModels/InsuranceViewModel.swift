import Combine
import Foundation

@MainActor
final class InsuranceViewModel: ObservableObject {
    @Published var plans: [Insurance] = []
    @Published var sortOrder: SortOrder = .lowToHigh

    enum SortOrder: String, CaseIterable {
        case lowToHigh = "保費由低至高"
        case highToLow = "保費由高至低"
    }

    var sortedPlans: [Insurance] {
        switch sortOrder {
        case .lowToHigh:
            return plans.sorted { $0.monthlyPremium < $1.monthlyPremium }
        case .highToLow:
            return plans.sorted { $0.monthlyPremium > $1.monthlyPremium }
        }
    }

    func currency(for plan: Insurance) -> String {
        plan.website.absoluteString.contains(".hk") ? "HKD" : "TWD"
    }

    func plansWithSimilarPremium(to plan: Insurance, count: Int = 3) -> [Insurance] {
        Array(sortedPlans
            .filter { $0.id != plan.id }
            .prefix(count))
    }

    init() {
        loadPlans()
    }

    func loadPlans() {
        plans = MockInsuranceRepository.seedPlans
    }
}
