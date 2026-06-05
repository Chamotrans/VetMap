import SwiftUI

struct ContentView: View {
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                HomeTab()
                    .tabItem {
                        Label("首頁", systemImage: "map.fill")
                    }
                    .accessibilityLabel("首頁")

                ClinicsTab()
                    .tabItem {
                        Label("診所", systemImage: "cross.case.fill")
                    }
                    .accessibilityLabel("診所")

                ProductsTab()
                    .tabItem {
                        Label("好物", systemImage: "shippingbox.fill")
                    }
                    .accessibilityLabel("好物")

                ProfileTab()
                    .tabItem {
                        Label("我的", systemImage: "person.fill")
                    }
                    .accessibilityLabel("我的")
            }
            .tint(AppTheme.primary)

            if !networkMonitor.isConnected {
                Text("離線模式 — 顯示本機資料")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.warning)
            }
        }
    }
}

#Preview {
    ContentView()
}

enum AppTheme {
    static let primary = Color.teal
    static let accent = Color.indigo
    static let warning = Color.orange
    static let screenBackground = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemGroupedBackground)
    static let cardRadius: CGFloat = 8
    static let compactRadius: CGFloat = 6
    static let hairline = Color(.separator).opacity(0.18)
}

struct AppCardModifier: ViewModifier {
    var fill: Color = Color(.systemBackground)
    var stroke: Color = AppTheme.hairline

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
    }
}

struct AppChipModifier: ViewModifier {
    var tint: Color = AppTheme.primary
    var isFilled = false

    func body(content: Content) -> some View {
        content
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(isFilled ? .white : tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isFilled ? tint : tint.opacity(0.11),
                in: RoundedRectangle(cornerRadius: AppTheme.compactRadius, style: .continuous)
            )
    }
}

extension View {
    func appCard(fill: Color = Color(.systemBackground), stroke: Color = AppTheme.hairline) -> some View {
        modifier(AppCardModifier(fill: fill, stroke: stroke))
    }

    func appChip(tint: Color = AppTheme.primary, isFilled: Bool = false) -> some View {
        modifier(AppChipModifier(tint: tint, isFilled: isFilled))
    }
}
