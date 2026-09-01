import Observation
import StoreKit

@MainActor
@Observable
final class SupportDeveloperViewModel {
    private let loadSupportPrice: () async -> String?
    private let purchaseSupport: () async throws -> Void

    private(set) var displayPrice: String?
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    private(set) var purchaseSucceeded = false
    private(set) var errorMessage: String?

    init(service: IAPService? = nil) {
        let service = service ?? IAPService()
        loadSupportPrice = {
            await service.loadSupportProduct()?.displayPrice
        }
        purchaseSupport = {
            guard let product = await service.loadSupportProduct() else {
                throw SupportDeveloperError.productUnavailable
            }
            try await service.purchaseSupport(product)
        }
    }

    /// Deterministic seam for model tests. Production continues to use
    /// StoreKit's product metadata and verified transaction path above.
    init(
        testingDisplayPrice: String?,
        testingPurchase: @escaping () async throws -> Void = {}
    ) {
        loadSupportPrice = { testingDisplayPrice }
        purchaseSupport = testingPurchase
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        purchaseSucceeded = false
        displayPrice = await loadSupportPrice()
        isLoading = false
        if displayPrice == nil {
            errorMessage = "暫時未能載入支持選項，請稍後重試。"
        }
    }

    func purchase() async {
        guard displayPrice != nil else {
            errorMessage = "支持選項尚未準備好，請先重試載入。"
            return
        }
        isPurchasing = true
        errorMessage = nil
        purchaseSucceeded = false
        defer { isPurchasing = false }

        do {
            try await purchaseSupport()
            purchaseSucceeded = true
        } catch IAPError.userCancelled {
            // Cancellation is not a failure message and should be quiet.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum SupportDeveloperError: LocalizedError {
    case productUnavailable

    var errorDescription: String? {
        "暫時未能載入支持選項，請稍後重試。"
    }
}
