import SwiftUI

struct ProductDetailView: View {
    let product: PetProduct

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                imagePlaceholder

                VStack(alignment: .leading, spacing: 12) {
                    Text(product.name)
                        .font(.title3.weight(.bold))

                    if !product.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(product.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    tagsSection
                }
                .padding(.horizontal, 16)

                if let officialURL = product.affiliateURL {
                    officialLinkButton(officialURL)
                        .padding(.horizontal, 16)
                }

                Text("服務資料及外部連結只供目錄與參考，最新內容以服務供應商官方資料為準。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("服務詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                CatalogFavoriteButton(itemID: product.id, kind: .service)
            }
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

    private func officialLinkButton(_ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Image(systemName: "globe")
                Text("查看官方資料")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
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
                name: "香港寵物美容服務",
                description: "提供寵物美容及護理服務。",
                category: "美容",
                price: .zero,
                currency: "HKD",
                clinicId: nil,
                affiliateURL: URL(string: "https://example.com"),
                imageURL: nil,
                tags: ["寵物美容"],
                createdAt: Date()
            )
        )
    }
}
