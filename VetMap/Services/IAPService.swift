// REQUIRES: StoreKit 2 (iOS 17+)

import StoreKit
import SwiftUI

// MARK: - StoreKit 2 IAP Products
// Legacy premium IDs retain their historical entitlement semantics. The drink
// support items are deliberately separate consumables, never entitlements.

@MainActor
@Observable
final class IAPService {
    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isPremium: Bool = false

    static let supportDrinkProductID = "com.vetmap.app.support.drink"
    static let supportHandcraftedDrinkProductID = "com.vetmap.app.support.handcrafted_drink"
    static let supportMealProductID = "com.vetmap.app.support.meal"

    static let supportProductIDs = [
        supportDrinkProductID,
        supportHandcraftedDrinkProductID,
        supportMealProductID
    ]

    @ObservationIgnored private let premiumProductIDs = [
        "com.vetmap.premium.monthly",
        "com.vetmap.premium.yearly"
    ]

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

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
            let fetched = try await Product.products(for: premiumProductIDs)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            print("載入產品失敗：\(error.localizedDescription)")
        }
    }

    /// Loads only the optional, one-time support products. StoreKit display
    /// prices are the sole prices shown to guardians.
    func loadSupportProducts() async -> [Product] {
        do {
            let fetched = try await Product.products(for: Self.supportProductIDs)
            let order = Dictionary(
                uniqueKeysWithValues: Self.supportProductIDs.enumerated().map { ($1, $0) }
            )
            return fetched.sorted {
                order[$0.id, default: .max] < order[$1.id, default: .max]
            }
        } catch {
            print("載入支持產品失敗：\(error.localizedDescription)")
            return []
        }
    }

    func purchaseSupport(_ product: Product) async throws {
        guard Self.supportProductIDs.contains(product.id) else {
            throw IAPError.unknown
        }
        try await purchase(product)
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
                if premiumProductIDs.contains(transaction.productID) {
                    purchasedProductIDs.insert(transaction.productID)
                    isPremium = true
                }
            }
        }
    }

    private func handle(_ transaction: StoreKit.Transaction) async {
        if premiumProductIDs.contains(transaction.productID) {
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
