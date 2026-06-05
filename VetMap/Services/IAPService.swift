// REQUIRES: StoreKit 2 (iOS 17+)

import StoreKit
import SwiftUI

// MARK: - ⚠️ DUMMY SEED DATA — 僅供開發測試用，上線前需替換為真實 StoreKit 產品

@MainActor
final class IAPService: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isPremium: Bool = false

    private let productIDs = [
        "com.vetmap.premium.monthly",
        "com.vetmap.premium.yearly"
    ]

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handle(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: productIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            print("載入產品失敗：\(error.localizedDescription)")
        }
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await handle(transaction)
                await transaction.finish()
            } else {
                throw IAPError.verificationFailed
            }
        case .userCancelled:
            throw IAPError.userCancelled
        case .pending:
            throw IAPError.pending
        @unknown default:
            throw IAPError.unknown
        }
    }

    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                await handle(transaction)
            }
        }
    }

    func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIDs.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)
                    isPremium = true
                }
            }
        }
    }

    private func handle(_ transaction: StoreKit.Transaction) async {
        if productIDs.contains(transaction.productID) {
            purchasedProductIDs.insert(transaction.productID)
            isPremium = true
        }
    }
}

enum IAPError: LocalizedError {
    case userCancelled
    case pending
    case verificationFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "購買已取消"
        case .pending:
            return "購買正在處理中，請稍後再試"
        case .verificationFailed:
            return "購買驗證失敗，請重新嘗試"
        case .unknown:
            return "發生未知錯誤，請稍後再試"
        }
    }
}
