import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: (label: String, action: () -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 56, height: 56)
                .background(
                    AppTheme.primary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let action {
                Button(action: action.action) {
                    Label(action.label, systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appCard()
    }
}

extension EmptyStateView {
    static var noResults: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "找不到相關結果",
            subtitle: "嘗試調整搜尋條件或篩選器"
        )
    }

    static var noReviews: EmptyStateView {
        EmptyStateView(
            icon: "text.bubble",
            title: "尚無評價",
            subtitle: "成為第一個分享的吧！"
        )
    }

    static var noQuotes: EmptyStateView {
        EmptyStateView(
            icon: "doc.text",
            title: "尚無報價記錄",
            subtitle: "成為第一個分享的吧！"
        )
    }

    static var noFavorites: EmptyStateView {
        EmptyStateView(
            icon: "heart",
            title: "尚未收藏任何內容",
            subtitle: "瀏覽診所與好物，將喜愛的內容收藏於此"
        )
    }

    static var locationDisabled: EmptyStateView {
        EmptyStateView(
            icon: "location.slash",
            title: "無法取得位置",
            subtitle: "請在系統設定中允許 VetMap 取用位置權限"
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        EmptyStateView.noResults
        EmptyStateView.noReviews
        EmptyStateView.noFavorites
    }
    .padding()
    .background(AppTheme.screenBackground)
}
