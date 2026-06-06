import SwiftUI

struct ProductListView: View {
    @ObservedObject var viewModel: ProductViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var productForSheet: PetProduct?
    @State private var searchText = ""

    private var displayedProducts: [PetProduct] {
        let products = viewModel.filteredProducts
        guard !searchText.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    var body: some View {
        ScrollView {
            CategoryFilterRow(selected: $viewModel.selectedCategory)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(displayedProducts) { product in
                    productButton(for: product)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground)
        .searchable(text: $searchText, prompt: "搜尋寵物用品")
        .sheet(item: $productForSheet) { product in
            NavigationStack {
                ProductDetailView(product: product)
            }
        }
    }

    @ViewBuilder
    private func productButton(for product: PetProduct) -> some View {
        if horizontalSizeClass == .regular {
            Button {
                productForSheet = product
            } label: {
                ProductCardView(product: product)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                ProductDetailView(product: product)
            } label: {
                ProductCardView(product: product)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct CategoryFilterRow: View {
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ProductViewModel.categories, id: \.self) { category in
                    Button {
                        selected = category
                    } label: {
                        Text(category)
                            .appChip(
                                tint: selected == category ? AppTheme.primary : AppTheme.accent,
                                isFilled: selected == category
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }
}

private struct ProductCardView: View {
    let product: PetProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            productImage
                .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text(product.category)
                    .appChip(tint: categoryColor, isFilled: false)

                Text("")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.warning)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .appCard()
    }

    private var categoryColor: Color {
        switch product.category {
        case "食品": return .green
        case "玩具": return .orange
        case "保健": return .purple
        case "藥品": return .red
        default: return AppTheme.accent
        }
    }

    private var productImage: some View {
        KingfisherImage(
            url: product.imageURL,
            placeholder: .pawprint,
            contentMode: .fill,
            cornerRadius: AppTheme.compactRadius,
            showsCardBorder: false
        )
    }
}

private extension PetProduct {
    var formattedPrice: String {
        let symbol = currency == "HKD" ? "HK$" : "NT$"
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
        return "\(symbol)\(amount)"
    }
}

#Preview {
    NavigationStack {
        ProductListView(viewModel: ProductViewModel())
    }
}
