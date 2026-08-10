import Foundation
import SwiftUI

@MainActor
final class ClinicFavoritesStore: ObservableObject {
    static let shared = ClinicFavoritesStore()

    @Published private(set) var clinicIDs: [String]
    @Published private(set) var updatingClinicIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let firebase: FirebaseService
    private var loadedUserID: String?
    private var cacheOwnerUserID: String?
    private var activeRefreshTask: Task<Void, Never>?

    private init(
        defaults: UserDefaults = .standard,
        firebase: FirebaseService = .shared
    ) {
        self.defaults = defaults
        self.firebase = firebase
        cacheOwnerUserID = defaults.string(forKey: ClinicFavorites.cacheOwnerKey)
        clinicIDs = ClinicFavorites.decode(
            defaults.string(forKey: ClinicFavorites.storageKey) ?? "[]"
        )
    }

    func contains(_ clinicID: String) -> Bool {
        clinicIDs.contains(clinicID)
    }

    func isUpdating(_ clinicID: String) -> Bool {
        updatingClinicIDs.contains(clinicID)
    }

    func refresh(force: Bool = false) async {
        guard let userID = AuthViewModel.shared.user?.uid, !userID.isEmpty else {
            clearLocalSession()
            return
        }
        if let activeRefreshTask {
            await activeRefreshTask.value
            if loadedUserID != userID {
                await refresh(force: force)
            }
            return
        }
        guard force || loadedUserID != userID else { return }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(for: userID)
        }
        activeRefreshTask = task
        await task.value
        activeRefreshTask = nil
    }

    private func performRefresh(for userID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            if let cacheOwnerUserID, cacheOwnerUserID != userID {
                clinicIDs = []
                defaults.removeObject(forKey: ClinicFavorites.storageKey)
            }
            let remoteIDs = try await firebase.fetchFavoriteClinicIDs()
            guard AuthViewModel.shared.user?.uid == userID else {
                clearLocalSession()
                return
            }
            let migrationKey = ClinicFavorites.cloudMigrationKey(for: userID)
            if !defaults.bool(forKey: migrationKey), !clinicIDs.isEmpty {
                let mergedIDs = ClinicFavorites.normalized(remoteIDs + clinicIDs)
                for clinicID in mergedIDs where !remoteIDs.contains(clinicID) {
                    try await firebase.setClinicFavorite(clinicID, isFavorite: true)
                }
                clinicIDs = mergedIDs
                defaults.set(true, forKey: migrationKey)
            } else {
                clinicIDs = remoteIDs
            }
            loadedUserID = userID
            cacheOwnerUserID = userID
            persist()
            errorMessage = nil
        } catch {
            errorMessage = "無法同步收藏：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "ClinicFavoritesStore.refresh")
        }
    }

    func setFavorite(_ clinicID: String, isFavorite: Bool) async {
        guard ClinicFavorites.isValidClinicID(clinicID) else {
            errorMessage = FirebaseError.invalidFavoriteClinicID.localizedDescription
            return
        }
        guard !updatingClinicIDs.contains(clinicID) else { return }
        guard let userID = AuthViewModel.shared.user?.uid, !userID.isEmpty else {
            errorMessage = FirebaseError.authenticationRequired.localizedDescription
            return
        }

        if loadedUserID != userID {
            await refresh()
        }
        let previousIDs = clinicIDs
        let nextIDs = ClinicFavorites.setting(
            clinicID,
            isFavorite: isFavorite,
            in: previousIDs
        )
        guard nextIDs != previousIDs else {
            if isFavorite && !previousIDs.contains(clinicID) {
                errorMessage = "最多可收藏 \(ClinicFavorites.maximumCount) 間診所。"
            }
            return
        }

        clinicIDs = nextIDs
        persist()
        updatingClinicIDs.insert(clinicID)
        defer { updatingClinicIDs.remove(clinicID) }

        do {
            try await firebase.setClinicFavorite(clinicID, isFavorite: isFavorite)
            guard AuthViewModel.shared.user?.uid == userID else {
                clearLocalSession()
                return
            }
            cacheOwnerUserID = userID
            persist()
            errorMessage = nil
            Haptics.light()
        } catch {
            if AuthViewModel.shared.user?.uid == userID {
                clinicIDs = previousIDs
                persist()
                errorMessage = "無法更新收藏：\(error.localizedDescription)"
            } else {
                clearLocalSession()
            }
            CrashReporting.recordError(error, domain: "ClinicFavoritesStore.setFavorite")
        }
    }

    func clearLocalSession() {
        clinicIDs = []
        updatingClinicIDs = []
        loadedUserID = nil
        cacheOwnerUserID = nil
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        errorMessage = nil
        defaults.removeObject(forKey: ClinicFavorites.storageKey)
        defaults.removeObject(forKey: ClinicFavorites.cacheOwnerKey)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func persist() {
        defaults.set(
            ClinicFavorites.encode(clinicIDs),
            forKey: ClinicFavorites.storageKey
        )
        if let cacheOwnerUserID {
            defaults.set(cacheOwnerUserID, forKey: ClinicFavorites.cacheOwnerKey)
        }
    }
}

struct FavoriteButton: View {
    let clinicID: String
    @ObservedObject private var auth = AuthViewModel.shared
    @ObservedObject private var favorites = ClinicFavoritesStore.shared
    @State private var showLogin = false
    @State private var desiredFavoriteAfterLogin: Bool?

    private var isFavorite: Bool {
        auth.authState == .signedIn && favorites.contains(clinicID)
    }

    var body: some View {
        Button {
            let desiredValue = !isFavorite
            if auth.authState == .signedIn {
                Task {
                    await favorites.setFavorite(clinicID, isFavorite: desiredValue)
                }
            } else {
                desiredFavoriteAfterLogin = desiredValue
                showLogin = true
            }
        } label: {
            ZStack {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? Color.red : Color.secondary)
                    .font(.title3)
                    .opacity(favorites.isUpdating(clinicID) ? 0.25 : 1)

                if favorites.isUpdating(clinicID) {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(favorites.isUpdating(clinicID))
        .accessibilityLabel(isFavorite ? "取消收藏" : "收藏診所")
        .accessibilityHint(
            auth.authState == .signedIn
                ? "同步到你的 VetMap 帳戶"
                : "登入後同步到你的 VetMap 帳戶"
        )
        .fullScreenCover(isPresented: $showLogin, onDismiss: {
            if auth.authState != .signedIn {
                desiredFavoriteAfterLogin = nil
            }
        }) {
            LoginView(authViewModel: auth)
        }
        .alert(
            "收藏診所",
            isPresented: Binding(
                get: { favorites.errorMessage != nil },
                set: { if !$0 { favorites.dismissError() } }
            )
        ) {
            Button("好", role: .cancel) { favorites.dismissError() }
        } message: {
            Text(favorites.errorMessage ?? "")
        }
        .task(id: auth.user?.uid) {
            if auth.authState == .signedIn {
                await favorites.refresh(force: true)
            }
        }
        .onChange(of: auth.authState) { _, newState in
            if newState == .signedOut {
                desiredFavoriteAfterLogin = nil
                favorites.clearLocalSession()
                return
            }
            guard newState == .signedIn,
                  let desiredValue = desiredFavoriteAfterLogin else { return }
            desiredFavoriteAfterLogin = nil
            showLogin = false
            Task {
                await favorites.refresh(force: true)
                await favorites.setFavorite(clinicID, isFavorite: desiredValue)
            }
        }
    }
}
