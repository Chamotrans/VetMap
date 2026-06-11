import SwiftUI

struct ProductDetailView: View {
    let product: PetProduct
    @State private var showNoURLAler = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                imagePlaceholder

                VStack(alignment: .leading, spacing: 12) {
                    Text(product.name)
                        .font(.title3.weight(.bold))

                    Text(product.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    tagsSection
                }
                .padding(.horizontal, 16)

                if let clinic = clinicName {
                    clinicSection(clinicName: clinic)
                        .padding(.horizontal, 16)
                }

                purchaseButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("商戶詳情")
        .navigationBarTitleDisplayMode(.inline)
        .alert("無法開啟連結", isPresented: $showNoURLAler) {
            Button("確定", role: .cancel) {}
        } message: {
            Text("此商戶目前沒有連結，請聯繫相關診所查詢。")
        }
    }

    private var imagePlaceholder: some View {
        KingfisherImage(
            url: product.imageURL,
            placeholder: .pawprint,
            contentMode: .fill,
            cornerRadius: AppTheme.cardRadius,
            showsCardBorder: false
        )
        .frame(height: 240)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(product.category)
                    .appChip(tint: categoryColor, isFilled: true)

                ForEach(product.tags, id: \.self) { tag in
                    Text(tag)
                        .appChip(tint: AppTheme.accent, isFilled: false)
                }
            }
        }
    }

    private func clinicSection(clinicName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("適用診所")
                .font(.headline)

            HStack(spacing: 8) {
                Image(systemName: "cross.case.fill")
                    .foregroundStyle(AppTheme.primary)
                Text(clinicName)
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(12)
            .appCard(fill: AppTheme.primary.opacity(0.08), stroke: AppTheme.primary.opacity(0.2))
        }
    }

    private var purchaseButton: some View {
        Button {
            if let url = product.affiliateURL {
                UIApplication.shared.open(url)
            } else {
                showNoURLAler = true
            }
        } label: {
            HStack {
                Image(systemName: "storefront.fill")
                Text("前往商戶")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var clinicName: String? {
        guard let clinicId = product.clinicId else { return nil }
        return MockClinicRepository.hkClinics.first { $0.id == clinicId }?.name
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
}

#Preview {
    NavigationStack {
        ProductDetailView(
            product: PetProduct(
                id: "preview",
                name: "皇家F32理想體態貓糧",
                description: "專為成貓設計的均衡營養配方。",
                category: "食品",
                price: Decimal(1200),
                currency: "TWD",
                clinicId: "taipei-anxin",
                affiliateURL: URL(string: "https://example.com"),
                imageURL: nil,
                tags: ["貓糧", "成貓"],
                createdAt: Date()
            )
        )
    }
}
