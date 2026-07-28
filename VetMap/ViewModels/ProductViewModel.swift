import Foundation

@MainActor
@Observable
final class ProductViewModel {
    var products: [PetProduct] = []
    var selectedCategory: String = "全部"
    var isLoading = false
    var errorMessage: String?

    static let categories = ["全部", "用品", "美容", "善終", "食品", "玩具", "保健", "藥品"]

    var filteredProducts: [PetProduct] {
        if selectedCategory == "全部" {
            return products
        }
        return products.filter { $0.category == selectedCategory }
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            products = try await FirebaseService.shared
                .fetchProducts(category: nil)
                .sorted {
                    $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
        } catch {
            errorMessage = "暫時無法載入香港寵物服務目錄，請稍後再試。"
        }
    }
}
