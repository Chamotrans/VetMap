import SwiftUI

struct ProductsTab: View {
    @State private var productViewModel = ProductViewModel()
    @State private var insuranceViewModel = InsuranceViewModel()
    @State private var selectedSegment: Segment = .products

    enum Segment: String, CaseIterable {
        case products = "好物"
        case insurance = "保險"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("分類", selection: $selectedSegment) {
                    ForEach(Segment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))

                switch selectedSegment {
                case .products:
                    ProductListView(viewModel: productViewModel)
                case .insurance:
                    InsuranceListView(viewModel: insuranceViewModel)
                }
            }
            .animation(.default, value: selectedSegment)
            .navigationTitle("毛孩好物 (\(MockProductRepository.seedProducts.count))")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ProductsTab()
}
