import SwiftUI

struct ErrorBanner: View {
    let icon: String
    let message: String
    var tint: Color = AppTheme.warning
    var onDismiss: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(3)

            Spacer(minLength: 8)

            if let onDismiss {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("關閉")
            }
        }
        .padding(12)
        .background(
            tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .offset(y: isVisible ? 0 : -120)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isVisible)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }
}

struct ErrorRetryView: View {
    let icon: String
    let title: String
    let message: String
    var retryLabel: String = "重試"
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.warning)
                .frame(width: 80, height: 80)
                .background(
                    AppTheme.warning.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let onRetry {
                Button {
                    onRetry()
                } label: {
                    Label(retryLabel, systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: 180)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: AppTheme.cardRadius))
                .tint(AppTheme.primary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.screenBackground)
    }
}

struct NetworkErrorView: View {
    var onRetry: (() -> Void)?

    var body: some View {
        ErrorRetryView(
            icon: "wifi.slash",
            title: "網絡連線異常",
            message: "請檢查你的網絡連線後再試。",
            retryLabel: "檢查連線",
            onRetry: onRetry
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        ErrorBanner(
            icon: "externaldrive.badge.exclamationmark",
            message: "診所已加入目前列表，但暫時無法儲存到本機。",
            onDismiss: {}
        )
        .padding(.horizontal, 16)
        .padding(.top, 60)

        Spacer()

        ErrorRetryView(
            icon: "exclamationmark.triangle.fill",
            title: "發生錯誤",
            message: "無法載入診所資料，請稍後再試。",
            onRetry: {}
        )

        Spacer()

        NetworkErrorView(onRetry: {})
    }
    .background(AppTheme.screenBackground)
}
