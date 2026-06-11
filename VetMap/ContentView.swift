import SwiftUI

struct ContentView: View {
    @State private var networkMonitor = NetworkMonitor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: SidebarTab? = .home
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    enum SidebarTab: String, CaseIterable {
        case home = "首頁"
        case clinics = "診所"
        case products = "好物"
        case profile = "我的"

        var systemImage: String {
            switch self {
            case .home: "map.fill"
            case .clinics: "cross.case.fill"
            case .products: "shippingbox.fill"
            case .profile: "person.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if horizontalSizeClass == .regular {
                ipadLayout
            } else {
                iphoneLayout
            }

            if !networkMonitor.isConnected {
                Text("離線模式 — 顯示本機資料")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.warning)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
    }

    private var iphoneLayout: some View {
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
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .navigationTitle("VetMap")
            .listStyle(.sidebar)
        } detail: {
            Group {
                if let selectedTab {
                    switch selectedTab {
                    case .home:
                        HomeTab()
                    case .clinics:
                        ClinicsTab()
                    case .products:
                        ProductsTab()
                    case .profile:
                        ProfileTab()
                    }
                } else {
                    ContentUnavailableView(
                        "選擇分頁",
                        systemImage: "sidebar.left",
                        description: Text("從側邊欄選擇一個分頁")
                    )
                }
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
