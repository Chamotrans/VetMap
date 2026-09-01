import Observation
import StoreKit

@MainActor
@Observable
final class SupportDeveloperViewModel {
    struct SupportOption: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let displayPrice: String?
    }

    private struct SupportCopy {
        let id: String
        let title: String
        let description: String
    }

    private static let supportCopy = [
        SupportCopy(
            id: IAPService.supportDrinkProductID,
            title: "轉凍飲",
            description: "天口咁熱請我飲杯凍飲"
        ),
        SupportCopy(
            id: IAPService.supportHandcraftedDrinkProductID,
            title: "手搖飲品",
            description: "間中飲杯快樂肥仔水唔過分吧"
        ),
        SupportCopy(
            id: IAPService.supportMealProductID,
            title: "肚餓都只食良",
            description: "開發不易，支持IT狗也有選擇的能力"
        )
    ]

    private let loadSupportPrices: () async -> [String: String]
    private let purchaseSupport: (String) async throws -> Void

    private(set) var displayPrices: [String: String] = [:]
    private(set) var isLoading = false
    private(set) var purchasingProductID: String?
    private(set) var purchaseSucceeded = false
    private(set) var errorMessage: String?

    var supportOptions: [SupportOption] {
        Self.supportCopy.map {
            SupportOption(
                id: $0.id,
                title: $0.title,
                description: $0.description,
                displayPrice: displayPrices[$0.id]
            )
        }
    }

    var isPurchasing: Bool { purchasingProductID != nil }

    init(service: IAPService? = nil) {
        let service = service ?? IAPService()
        loadSupportPrices = {
            Dictionary(
                uniqueKeysWithValues: await service.loadSupportProducts().map { ($0.id, $0.displayPrice) }
            )
        }
        purchaseSupport = { productID in
            guard let product = await service.loadSupportProducts().first(where: { $0.id == productID }) else {
                throw SupportDeveloperError.productUnavailable
            }
            try await service.purchaseSupport(product)
        }
    }

    /// Deterministic seam for model tests. Production continues to use
    /// StoreKit's product metadata and verified transaction path above.
    init(
        testingDisplayPrices: [String: String],
        testingPurchase: @escaping (String) async throws -> Void = { _ in }
    ) {
        loadSupportPrices = { testingDisplayPrices }
        purchaseSupport = testingPurchase
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        purchaseSucceeded = false
        displayPrices = await loadSupportPrices()
        isLoading = false
        if displayPrices.isEmpty {
            errorMessage = "暫時未能載入支持選項，請稍後重試。"
        }
    }

    func purchase(productID: String) async {
        guard displayPrices[productID] != nil else {
            errorMessage = "支持選項尚未準備好，請先重試載入。"
            return
        }
        purchasingProductID = productID
        errorMessage = nil
        purchaseSucceeded = false
        defer { purchasingProductID = nil }

        do {
            try await purchaseSupport(productID)
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
