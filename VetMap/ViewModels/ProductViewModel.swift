import Combine
import Foundation

@MainActor
final class ProductViewModel: ObservableObject {
    @Published var products: [PetProduct] = []
    @Published var selectedCategory: String = "全部"

    static let categories = ["全部", "用品", "美容", "善終", "食品", "玩具", "保健", "藥品"]

    var filteredProducts: [PetProduct] {
        if selectedCategory == "全部" {
            return products
        }
        return products.filter { $0.category == selectedCategory }
    }

    init() {
        loadProducts()
    }

    func loadProducts() {
        products = MockProductRepository.seedProducts
    }
}
