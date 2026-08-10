import Foundation

@MainActor
@Observable
final class InsuranceViewModel {
    var plans: [Insurance] = []
    var sortOrder: SortOrder = .lowToHigh
    var isLoading = false
    var errorMessage: String?

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
        "HKD"
    }

    func formattedPremium(_ amount: Decimal) -> String {
        guard amount > .zero else { return "官方報價" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let value = formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
        return "HK$\(value)"
    }

    func plansWithSimilarPremium(to plan: Insurance, count: Int = 3) -> [Insurance] {
        Array(sortedPlans
            .filter { $0.id != plan.id }
            .prefix(count))
    }

    func loadPlans() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            plans = try await FirebaseService.shared.fetchInsurances()
        } catch {
            errorMessage = String(
                localized: "暫時無法載入香港寵物保險目錄，請稍後再試。"
            )
        }
    }
}
