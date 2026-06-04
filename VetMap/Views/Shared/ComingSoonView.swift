import SwiftUI

struct ComingSoonView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.title2.weight(.bold))

                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .appCard()
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle(title)
        }
    }
}

#Preview {
    ComingSoonView(
        title: "獸醫診所",
        subtitle: "搜尋、篩選與詳細頁會在地圖主體完成後接上。",
        systemImage: "list.bullet.rectangle"
    )
}
