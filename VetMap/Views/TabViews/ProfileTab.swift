import SwiftUI

/// App-wide feature flags. Premium/IAP is hidden for the free v1 launch because
/// no subscription products are configured in App Store Connect yet. Flip to
/// `true` once IAP products are live and the first subscription is in review.
enum FeatureFlags {
    static let premiumEnabled = false
}

struct ProfileTab: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @ObservedObject private var admin = AdminViewModel.shared
    @State private var showLogin = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            Group {
                switch authViewModel.authState {
                case .loading:
                    loadingView
                case .signedOut:
                    signedOutView
                case .signedIn:
                    signedInView
                }
            }
            .navigationTitle("我的")
            .background(AppTheme.screenBackground)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(authViewModel: authViewModel)
        }
        .onChange(of: authViewModel.authState) { _, newState in
            if newState == .signedIn {
                showLogin = false
            }
            admin.refresh(uid: authViewModel.user?.uid)
        }
        .onAppear {
            admin.refresh(uid: authViewModel.user?.uid)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入中…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Signed Out

    private var signedOutView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pawprint.circle")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.primary.opacity(0.6))

            VStack(spacing: 8) {
                Text("登入以解鎖完整功能")
                    .font(.title3.weight(.semibold))

                Text("收藏診所、管理會員訂閱、分享報價")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showLogin = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.fill")
                    Text("登入 / 註冊")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .foregroundStyle(.white)
            .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 40)
            .accessibilityLabel("登入或註冊")
            .accessibilityHint("開啟登入頁面")

            Spacer()
        }
        .padding(.bottom, 40)
    }

    // MARK: - Signed In

    private var signedInView: some View {
        List {
            Section {
                userHeader
            }

            Section("我的收藏") {
                NavigationLink {
                    ComingSoonView(
                        title: "我的收藏",
                        subtitle: "收藏的診所與好物將顯示在此。",
                        systemImage: "heart.fill"
                    )
                } label: {
                    Label("收藏診所", systemImage: "building.2.fill")
                }

                NavigationLink {
                    ComingSoonView(
                        title: "我的收藏",
                        subtitle: "收藏的好物將顯示在此。",
                        systemImage: "heart.fill"
                    )
                } label: {
                    Label("收藏好物", systemImage: "shippingbox.fill")
                }
            }

            if admin.isAdmin {
                Section("管理") {
                    NavigationLink {
                        AdminPortalView()
                    } label: {
                        Label {
                            HStack {
                                Text("管理後台")
                                if ModerationStore.shared.totalPendingCount > 0 {
                                    Spacer()
                                    Text("\(ModerationStore.shared.totalPendingCount)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.warning, in: Capsule())
                                }
                            }
                        } icon: {
                            Image(systemName: "shield.lefthalf.filled")
                        }
                    }
                    .accessibilityLabel("管理後台")
                }
            }

            if FeatureFlags.premiumEnabled {
                Section("Premium 會員") {
                    NavigationLink {
                        PremiumView()
                    } label: {
                        Label("升級 Premium", systemImage: "crown.fill")
                    }
                    .accessibilityLabel("升級 Premium")
                    .accessibilityHint("查看 Premium 會員方案")

                    NavigationLink {
                        PremiumView()
                    } label: {
                        Label("訂閱管理", systemImage: "creditcard.fill")
                    }
                }
            }

            Section("顯示") {
                Toggle(isOn: .constant(false)) {
                    Label("高對比模式", systemImage: "circle.lefthalf.filled")
                }
            }

            Section("設定") {
                NavigationLink {
                    AccountSettingsView(authViewModel: authViewModel)
                } label: {
                    Label("帳號設定", systemImage: "gearshape.fill")
                }

                Link(destination: URL(string: "https://vetmap-app.web.app")!) {
                    Label("隱私政策", systemImage: "hand.raised.fill")
                }

                NavigationLink {
                    ComingSoonView(
                        title: "設定",
                        subtitle: "關於 VetMap。",
                        systemImage: "gearshape.fill"
                    )
                } label: {
                    Label("關於 VetMap", systemImage: "info.circle.fill")
                }
            }

            #if DEBUG
            Section("開發者") {
                Toggle(isOn: $admin.debugAdminOverride) {
                    Label("模擬管理員身分", systemImage: "hammer.fill")
                }
                .tint(AppTheme.primary)
            }
            #endif

            Section {
                Button(role: .destructive) {
                    showSignOutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
                .accessibilityLabel("登出")
                .accessibilityHint("登出目前帳戶")
            }
        }
        .listStyle(.insetGrouped)
        .alert("確認登出", isPresented: $showSignOutAlert) {
            Button("取消", role: .cancel) {}
            Button("登出", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("確定要登出嗎？")
        }
    }

    // MARK: - User Header

    private var userHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(authViewModel.user?.displayName ?? "用戶")
                    .font(.headline)
                Text(authViewModel.user?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityLabel("用戶資料")
    }
}

#Preview {
    ProfileTab()
}
