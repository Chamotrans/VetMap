import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel.shared
    @State private var networkMonitor = NetworkMonitor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: SidebarTab? = AppLaunchFlags.initialTab
    @State private var phoneTab: SidebarTab = AppLaunchFlags.initialTab
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    enum SidebarTab: String, CaseIterable {
        case home = "首頁"
        case clinics = "診所"
        case products = "服務"
        case messages = "訊息"
        case profile = "我的"

        var systemImage: String {
            switch self {
            case .home: "map.fill"
            case .clinics: "cross.case.fill"
            case .products: "storefront.fill"
            case .messages: "bubble.left.and.bubble.right.fill"
            case .profile: "person.fill"
            }
        }
    }

    private static var visibleTabs: [SidebarTab] {
        SidebarTab.allCases.filter { tab in
            tab != .products || FeatureFlags.catalogEnabled
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
                Text("離線模式 — 雲端資料可能未更新")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(AppTheme.warning)
            }
        }
        .environmentObject(authViewModel)
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView()
        }
        .onAppear {
            // 只在已過 onboarding 時評估顯示評分提示。
            if hasSeenOnboarding {
                triggerRatingPromptIfNeeded()
            }
        }
        .onChange(of: hasSeenOnboarding) { _, seen in
            // Onboarding 完成後才評估顯示評分提示。
            if seen {
                triggerRatingPromptIfNeeded()
            }
        }
    }

    @State private var didTriggerRatingPrompt = false

    private func triggerRatingPromptIfNeeded() {
        guard !didTriggerRatingPrompt else { return }
        guard !AppLaunchFlags.isScreenshotMode else { return }
        didTriggerRatingPrompt = true
        RatingPrompt.requestReviewIfAppropriate()
    }

    private var iphoneLayout: some View {
        TabView(selection: $phoneTab) {
            HomeTab()
                .tabItem {
                    Label("首頁", systemImage: "map.fill")
                }
                .tag(SidebarTab.home)
                .accessibilityLabel("首頁")

            ClinicsTab()
                .tabItem {
                    Label("診所", systemImage: "cross.case.fill")
                }
                .tag(SidebarTab.clinics)
                .accessibilityLabel("診所")

            if FeatureFlags.catalogEnabled {
                ProductsTab()
                    .tabItem {
                        Label("服務", systemImage: "storefront.fill")
                    }
                    .tag(SidebarTab.products)
                    .accessibilityLabel("寵物服務及保險")
            }

            ChatListView()
                .tabItem {
                    Label("訊息", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(SidebarTab.messages)
                .accessibilityLabel("訊息")

            ProfileTab()
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(SidebarTab.profile)
                .accessibilityLabel("我的")
        }
        .tint(AppTheme.primary)
    }

    private var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Self.visibleTabs, id: \.self) { tab in
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
                    case .messages:
                        ChatListView()
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

/// 截圖模式（傳入 `-UITestSuppressPrompts`）：抑制系統權限／評分彈窗，
/// 令 ASO 自動截圖唔會俾對話框蓋住。
/// `-screenshotScreen <id>` 直接開指定畫面，俾 simctl 逐張截圖（毋須 UITest target）。
enum AppLaunchFlags {
    static let isScreenshotMode = ProcessInfo.processInfo.arguments.contains("-UITestSuppressPrompts")

    static var screenshotScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-screenshotScreen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static var initialTab: ContentView.SidebarTab {
        switch screenshotScreen {
        case "02-Clinics", "03-ClinicDetail": .clinics
        case "04-Community": .clinics
        case "04-Products": .products
        case "05-Messages": .messages
        case "05-Profile": .profile
        default: .home
        }
    }

    static var autoPresentClinic: Bool { screenshotScreen == "03-ClinicDetail" }
}

enum AppTheme {
    // Dark amber maintains readable white text for prominent controls while
    // retaining green exclusively for semantic open-status indicators.
    static let primary = Color(red: 0.64, green: 0.31, blue: 0.02)
    static let accent = Color(red: 0.29, green: 0.43, blue: 0.48)
    static let warning = Color(red: 0.74, green: 0.33, blue: 0.04)
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
