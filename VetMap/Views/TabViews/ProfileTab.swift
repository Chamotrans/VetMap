import SwiftUI

struct ProfileTab: View {
    @StateObject private var authViewModel = AuthViewModel()
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

            Section("Premium 會員") {
                NavigationLink {
                    PremiumView()
                } label: {
                    Label("升級 Premium", systemImage: "crown.fill")
                }

                NavigationLink {
                    PremiumView()
                } label: {
                    Label("訂閱管理", systemImage: "creditcard.fill")
                }
            }

            Section("設定") {
                NavigationLink {
                    ComingSoonView(
                        title: "設定",
                        subtitle: "設定功能即將推出。",
                        systemImage: "gearshape.fill"
                    )
                } label: {
                    Label("帳號設定", systemImage: "gearshape.fill")
                }

                NavigationLink {
                    ComingSoonView(
                        title: "設定",
                        subtitle: "隱私政策即將推出。",
                        systemImage: "gearshape.fill"
                    )
                } label: {
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
    }
}

#Preview {
    ProfileTab()
}
