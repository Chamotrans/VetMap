import SwiftUI
import UserNotifications

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
            // 只在已過 onboarding 時觸發系統彈窗，避免蓋住 onboarding 進場動畫
            if hasSeenOnboarding {
                triggerLaunchPrompts()
            }
        }
        .onChange(of: hasSeenOnboarding) { _, seen in
            // Onboarding 完成後才請求通知權限 / 評分
            if seen {
                triggerLaunchPrompts()
            }
        }
    }

    @State private var didTriggerLaunchPrompts = false

    private func triggerLaunchPrompts() {
        guard !didTriggerLaunchPrompts else { return }
        guard !AppLaunchFlags.isScreenshotMode else { return }
        didTriggerLaunchPrompts = true
        RatingPrompt.requestReviewIfAppropriate()
        requestNotificationPermission()
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
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
                        Label("好物", systemImage: "shippingbox.fill")
                    }
                    .tag(SidebarTab.products)
                    .accessibilityLabel("好物")
            }

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
        case "04-Products":
            preconditionFailure("04-Products is not a supported Build 7 screenshot route")
        case "05-Profile": .profile
        default: .home
        }
    }

    static var autoPresentClinic: Bool { screenshotScreen == "03-ClinicDetail" }
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
