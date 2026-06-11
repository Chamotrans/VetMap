import SwiftUI

#if canImport(Kingfisher)
import Kingfisher
#endif

/// 圖片顯示元件，優先使用 Kingfisher 快取，否則降級為 AsyncImage。
/// 提供載入中、佔位圖、錯誤狀態，並遵循 AppTheme 設計系統。
struct KingfisherImage: View {
    let url: URL?
    var placeholder: PlaceholderStyle = .default
    var contentMode: SwiftUI.ContentMode = .fill
    var cornerRadius: CGFloat = AppTheme.cardRadius
    var showsCardBorder = true

    enum PlaceholderStyle {
        case `default`
        case pawprint
        case systemImage(String)

        var systemName: String {
            switch self {
            case .default: return "photo"
            case .pawprint: return "pawprint.fill"
            case .systemImage(let name): return name
            }
        }
    }

    var body: some View {
        Group {
            if let url {
                #if canImport(Kingfisher)
                KFImage(url)
                    .placeholder { placeholderView }
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                #else
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholderView
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        errorFallback
                    @unknown default:
                        placeholderView
                    }
                }
                #endif
            } else {
                emptyState
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .if(showsCardBorder) {
            $0.appCard()
        }
    }

    // MARK: - States

    private var placeholderView: some View {
        ZStack {
            Color(AppTheme.surface)
            ProgressView()
                .tint(AppTheme.primary)
        }
    }

    private var errorFallback: some View {
        ZStack {
            Color(AppTheme.surface)
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .foregroundStyle(AppTheme.warning)
                Text("圖片載入失敗")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            Color(AppTheme.surface)
            VStack(spacing: 6) {
                Image(systemName: placeholder.systemName)
                    .font(.title3)
                    .foregroundStyle(AppTheme.primary.opacity(0.35))
                Text("暫無圖片")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Conditional modifier helper

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Convenience initializers

extension KingfisherImage {

    /// 寵物商品用，無圖片時顯示 pawprint
    static func product(_ url: URL?) -> KingfisherImage {
        KingfisherImage(url: url, placeholder: .pawprint)
    }

    /// 評價照片用，無圖片時顯示 photo
    static func review(_ url: URL?) -> KingfisherImage {
        KingfisherImage(url: url, placeholder: .default)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        KingfisherImage(
            url: URL(string: "https://picsum.photos/300")
        )
        .frame(width: 200, height: 200)

        KingfisherImage(url: nil)
            .frame(width: 200, height: 200)

        KingfisherImage(
            url: URL(string: "https://invalid.example/notfound.jpg")
        )
        .frame(width: 200, height: 200)

        KingfisherImage.product(nil)
            .frame(width: 80, height: 80)

        KingfisherImage.review(URL(string: "https://picsum.photos/150"))
            .frame(width: 80, height: 80)
    }
    .padding()
    .background(AppTheme.screenBackground)
}
#endif
