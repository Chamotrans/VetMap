import SwiftUI

/// App-wide feature flags. Premium/IAP is hidden for the free v1 launch because
/// no subscription products are configured in App Store Connect yet. Flip to
/// `true` once IAP products are live and the first subscription is in review.
enum FeatureFlags {
    static let premiumEnabled = false
    /// Public catalog reads are restricted to moderated Hong Kong records in
    /// Firestore. There is no bundled production catalog fallback.
    static let catalogEnabled = true
}

struct ProfileTab: View {
    @ObservedObject private var authViewModel = AuthViewModel.shared
    @ObservedObject private var admin = AdminViewModel.shared
    @ObservedObject private var favorites = ClinicFavoritesStore.shared
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
                Task { await favorites.refresh(force: true) }
            } else if newState == .signedOut {
                favorites.clearLocalSession()
            }
            admin.refresh(uid: authViewModel.user?.uid)
        }
        .onAppear {
            admin.refresh(uid: authViewModel.user?.uid)
            if authViewModel.authState == .signedIn {
                Task { await favorites.refresh() }
            }
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

                Text("收藏診所、投稿評論、分享報價")
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

            NavigationLink {
                AboutVetMapView()
            } label: {
                Label("關於 VetMap", systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
            }

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
                    ClinicFavoritesView()
                } label: {
                    Label {
                        HStack {
                            Text("收藏診所")
                            Spacer()
                            if !favorites.clinicIDs.isEmpty {
                                Text("\(favorites.clinicIDs.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "building.2.fill")
                    }
                }

                if FeatureFlags.catalogEnabled {
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
                    AboutVetMapView()
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

private struct ClinicFavoritesView: View {
    @ObservedObject private var favorites = ClinicFavoritesStore.shared
    @State private var clinicsViewModel = ClinicsViewModel()

    private var favoriteClinics: [VetClinic] {
        let clinicsByID = Dictionary(
            uniqueKeysWithValues: clinicsViewModel.filteredClinics.map { ($0.id, $0) }
        )
        return favorites.clinicIDs.compactMap { clinicsByID[$0] }
    }

    private var unavailableFavoriteCount: Int {
        max(0, favorites.clinicIDs.count - favoriteClinics.count)
    }

    var body: some View {
        List {
            if let errorMessage = favorites.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)

                    Button("重新同步") {
                        Task { await refresh() }
                    }
                }
            }

            if let networkError = clinicsViewModel.networkError {
                Section {
                    Label(networkError, systemImage: "wifi.slash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)

                    Button("重新載入診所") {
                        Task { await clinicsViewModel.retryLoad() }
                    }
                }
            }

            if favoriteClinics.isEmpty {
                Section {
                    if favorites.isLoading || clinicsViewModel.isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("正在同步收藏…")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 88)
                    } else {
                        ContentUnavailableView {
                            Label("尚未收藏診所", systemImage: "heart")
                        } description: {
                            Text("在診所詳情按心形按鈕，收藏會同步到你的 VetMap 帳戶。")
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
            } else {
                Section("\(favoriteClinics.count) 間診所") {
                    ForEach(favoriteClinics) { clinic in
                        NavigationLink {
                            ClinicDetailView(clinic: clinic)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(clinic.name)
                                    .font(.headline)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(clinic.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                ClinicAvailabilityBadge(clinic: clinic, compact: true)
                            }
                            .padding(.vertical, 5)
                        }
                        .accessibilityHint("開啟收藏診所詳情")
                    }
                    .onDelete(perform: removeFavorites)
                } footer: {
                    Text("按右上角「編輯」可移除收藏；變更會同步到你的帳戶。")
                }
            }

            if unavailableFavoriteCount > 0,
               !clinicsViewModel.isLoading,
               clinicsViewModel.networkError == nil {
                Section {
                    Label(
                        "另有 \(unavailableFavoriteCount) 項收藏目前未在公開診所目錄顯示。",
                        systemImage: "eye.slash"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("收藏診所")
        .toolbar {
            if !favoriteClinics.isEmpty {
                EditButton()
            }
        }
        .refreshable { await refresh() }
        .task { await refresh() }
    }

    private func refresh() async {
        await favorites.refresh(force: true)
        await clinicsViewModel.retryLoad()
    }

    private func removeFavorites(at offsets: IndexSet) {
        let clinicIDs = offsets.compactMap { index in
            favoriteClinics.indices.contains(index) ? favoriteClinics[index].id : nil
        }
        Task {
            for clinicID in clinicIDs {
                await favorites.setFavorite(clinicID, isFavorite: false)
            }
        }
    }
}

private struct AboutVetMapView: View {
    private let addressLookupURL = URL(
        string: "https://data.gov.hk/tc-data/dataset/hk-dpo-als_01-als"
    )!
    private let openDataTermsURL = URL(
        string: "https://data.gov.hk/tc/terms-and-conditions"
    )!

    var body: some View {
        List {
            Section("VetMap") {
                Text("香港寵物醫療及服務目錄，讓用戶搜尋診所、投稿資料、分享評價及報價。")
            }

            Section("診所資料") {
                Text("診所目錄由 VetMap 建立或經授權使用，並由 VetMap 整理及審核。資料可能隨時間變更，求診前請直接向診所確認。")

                Text("部分地址座標資料來源為香港特別行政區政府數字政策辦公室「地址搜尋服務」。相關資料的知識產權由香港特別行政區政府及有關機構擁有。VetMap 的使用不代表政府認可本 App。")

                Link(destination: addressLookupURL) {
                    Label("地址搜尋服務", systemImage: "map")
                }

                Link(destination: openDataTermsURL) {
                    Label("開放數據使用條款", systemImage: "doc.text")
                }
            }

            Section("更正資料") {
                Text("如發現診所地址、電話或營運狀態有誤，可在診所詳情頁舉報，或提交更新資料供審核。")
            }
        }
        .navigationTitle("關於 VetMap")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ProfileTab()
}
