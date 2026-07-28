import SwiftUI

struct ProductsTab: View {
    @State private var productViewModel = ProductViewModel()
    @State private var insuranceViewModel = InsuranceViewModel()
    @State private var selectedSegment: Segment = .products

    enum Segment: String, CaseIterable {
        case products = "服務"
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

                switch selectedSegment {
                case .products:
                    productContent
                case .insurance:
                    InsuranceListView(viewModel: insuranceViewModel)
                }
            }
            .organicBackground()
            .animation(.default, value: selectedSegment)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .task {
                await productViewModel.loadProducts()
                await insuranceViewModel.loadPlans()
            }
        }
    }

    @ViewBuilder
    private var productContent: some View {
        if productViewModel.isLoading && productViewModel.products.isEmpty {
            ProgressView("載入香港服務目錄…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = productViewModel.errorMessage,
                  productViewModel.products.isEmpty {
            ContentUnavailableView {
                Label("未能載入服務目錄", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重試") {
                    Task { await productViewModel.loadProducts() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else if productViewModel.products.isEmpty {
            ContentUnavailableView(
                "暫未有服務資料",
                systemImage: "storefront",
                description: Text("經審核的香港寵物服務將會顯示在此。")
            )
        } else {
            ProductListView(viewModel: productViewModel)
        }
    }

    private var navigationTitle: String {
        switch selectedSegment {
        case .products:
            "寵物服務 (\(productViewModel.products.count))"
        case .insurance:
            "寵物保險 (\(insuranceViewModel.plans.count))"
        }
    }
}

#Preview {
    ProductsTab()
}
