import SwiftUI
import StoreKit

enum PremiumPlan: String, CaseIterable {
    case monthly = "com.vetmap.premium.monthly"
    case yearly = "com.vetmap.premium.yearly"
}

@MainActor
final class PremiumViewModel: ObservableObject {
    @Published var selectedPlan: PremiumPlan?
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var purchaseSuccess = false

    private let service: IAPService

    var products: [Product] { service.products }
    var isPremium: Bool { service.isPremium }

    init(service: IAPService? = nil) {
        self.service = service ?? IAPService()
    }

    func loadProducts() async {
        await service.loadProducts()
    }

    func checkEntitlement() async {
        await service.checkEntitlement()
    }

    func purchase(_ plan: PremiumPlan) async {
        guard let product = service.products.first(where: { $0.id == plan.rawValue }) else {
            purchaseError = "找不到對應產品，請稍後再試"
            return
        }

        selectedPlan = plan
        isPurchasing = true
        purchaseError = nil
        purchaseSuccess = false

        do {
            try await service.purchase(product)
            purchaseSuccess = true
            isPurchasing = false
            Haptics.success()
        } catch let error as IAPError {
            purchaseError = error.localizedDescription
            isPurchasing = false
        } catch {
            purchaseError = "購買失敗：\(error.localizedDescription)"
            isPurchasing = false
        }
    }

    func restore() async {
        isPurchasing = true
        purchaseError = nil
        purchaseSuccess = false

        await service.restorePurchases()

        if service.isPremium {
            purchaseSuccess = true
        } else {
            purchaseError = "找不到可恢復的購買項目"
        }

        isPurchasing = false
    }

    func product(for plan: PremiumPlan) -> Product? {
        service.products.first { $0.id == plan.rawValue }
    }
}
