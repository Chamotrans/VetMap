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
    private var preparedUserID: String?
    private var sessionGeneration = 0
    private var activeRefreshTask: Task<Void, Never>?
    private var activeRefreshID: UUID?

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

    func prepareLocalSession(for userID: String) {
        guard !userID.isEmpty else {
            clearLocalSession()
            return
        }
        guard preparedUserID != userID else { return }

        // Owner-less values are the pre-account cache supported by the
        // one-time cloud migration below. Only discard data that is known to
        // belong to another Firebase account.
        if preparedUserID != nil && cacheOwnerUserID == nil {
            clearLocalSession()
        } else if let cacheOwnerUserID, cacheOwnerUserID != userID {
            clearLocalSession()
        }
        preparedUserID = userID
    }

    func refresh(force: Bool = false) async {
        guard let userID = AuthViewModel.shared.user?.uid, !userID.isEmpty else {
            clearLocalSession()
            return
        }
        prepareLocalSession(for: userID)
        if let activeRefreshTask {
            await activeRefreshTask.value
            return
        }
        guard force || loadedUserID != userID else { return }

        let generation = sessionGeneration
        let refreshID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(for: userID, generation: generation)
        }
        activeRefreshID = refreshID
        activeRefreshTask = task
        await task.value
        if activeRefreshID == refreshID {
            activeRefreshTask = nil
            activeRefreshID = nil
        }
    }

    private func performRefresh(for userID: String, generation: Int) async {
        guard generation == sessionGeneration else { return }
        isLoading = true
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }
        do {
            if let cacheOwnerUserID, cacheOwnerUserID != userID {
                clinicIDs = []
                defaults.removeObject(forKey: ClinicFavorites.storageKey)
            }
            let remoteIDs = try await firebase.fetchFavoriteClinicIDs(
                expectedUserID: userID
            )
            guard isCurrentSession(userID: userID, generation: generation) else { return }
            let migrationKey = ClinicFavorites.cloudMigrationKey(for: userID)
            if !defaults.bool(forKey: migrationKey), !clinicIDs.isEmpty {
                let mergedIDs = ClinicFavorites.normalized(remoteIDs + clinicIDs)
                for clinicID in mergedIDs where !remoteIDs.contains(clinicID) {
                    guard isCurrentSession(userID: userID, generation: generation) else {
                        return
                    }
                    try await firebase.setClinicFavorite(
                        clinicID,
                        isFavorite: true,
                        expectedUserID: userID
                    )
                }
                guard isCurrentSession(userID: userID, generation: generation) else { return }
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
            guard isCurrentSession(userID: userID, generation: generation) else { return }
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
        guard AuthViewModel.shared.user?.uid == userID else {
            return
        }
        cacheOwnerUserID = userID
        loadedUserID = userID

        let generation = sessionGeneration
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
            try await firebase.setClinicFavorite(
                clinicID,
                isFavorite: isFavorite,
                expectedUserID: userID
            )
            guard isCurrentSession(userID: userID, generation: generation) else { return }
            cacheOwnerUserID = userID
            persist()
            errorMessage = nil
            Haptics.light()
        } catch {
            guard isCurrentSession(userID: userID, generation: generation) else { return }
            clinicIDs = ClinicFavorites.setting(
                clinicID,
                isFavorite: !isFavorite,
                in: clinicIDs
            )
            persist()
            errorMessage = "無法更新收藏：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "ClinicFavoritesStore.setFavorite")
        }
    }

    func clearLocalSession() {
        sessionGeneration &+= 1
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        activeRefreshID = nil
        clinicIDs = []
        updatingClinicIDs = []
        loadedUserID = nil
        cacheOwnerUserID = nil
        preparedUserID = nil
        isLoading = false
        errorMessage = nil
        defaults.removeObject(forKey: ClinicFavorites.storageKey)
        defaults.removeObject(forKey: ClinicFavorites.cacheOwnerKey)
    }

    private func isCurrentSession(userID: String, generation: Int) -> Bool {
        AuthViewModel.shared.user?.uid == userID
            && generation == sessionGeneration
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

@MainActor
final class CatalogFavoritesStore: ObservableObject {
    static let shared = CatalogFavoritesStore()

    @Published private(set) var itemIDs: [String]
    @Published private(set) var updatingItemIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let defaults: UserDefaults
    private let firebase: FirebaseService
    private var loadedUserID: String?
    private var cacheOwnerUserID: String?
    private var preparedUserID: String?
    private var sessionGeneration = 0
    private var activeRefreshTask: Task<Void, Never>?
    private var activeRefreshID: UUID?

    private init(
        defaults: UserDefaults = .standard,
        firebase: FirebaseService = .shared
    ) {
        self.defaults = defaults
        self.firebase = firebase
        cacheOwnerUserID = defaults.string(forKey: SavedCatalogItems.cacheOwnerKey)
        if cacheOwnerUserID == nil {
            itemIDs = []
        } else {
            itemIDs = SavedCatalogItems.decode(
                defaults.string(forKey: SavedCatalogItems.storageKey) ?? "[]"
            )
        }
    }

    func contains(_ itemID: String) -> Bool {
        itemIDs.contains(itemID)
    }

    func isUpdating(_ itemID: String) -> Bool {
        updatingItemIDs.contains(itemID)
    }

    /// Discard a cache owned by a different Firebase account before any view
    /// can present it as belonging to the newly authenticated user.
    func prepareLocalSession(for userID: String) {
        guard !userID.isEmpty else {
            clearLocalSession()
            return
        }
        guard preparedUserID != userID else { return }

        if cacheOwnerUserID != userID {
            clearLocalSession()
        }
        preparedUserID = userID
    }

    func refresh(force: Bool = false) async {
        guard let userID = AuthViewModel.shared.user?.uid, !userID.isEmpty else {
            clearLocalSession()
            return
        }
        prepareLocalSession(for: userID)
        if let activeRefreshTask {
            await activeRefreshTask.value
            return
        }
        guard force || loadedUserID != userID else { return }

        let generation = sessionGeneration
        let refreshID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performRefresh(
                for: userID,
                generation: generation
            )
        }
        activeRefreshID = refreshID
        activeRefreshTask = task
        await task.value
        if activeRefreshID == refreshID {
            activeRefreshTask = nil
            activeRefreshID = nil
        }
    }

    private func performRefresh(for userID: String, generation: Int) async {
        guard generation == sessionGeneration else { return }
        isLoading = true
        defer {
            if generation == sessionGeneration {
                isLoading = false
            }
        }

        do {
            if let cacheOwnerUserID, cacheOwnerUserID != userID {
                itemIDs = []
                self.cacheOwnerUserID = nil
                defaults.removeObject(forKey: SavedCatalogItems.storageKey)
                defaults.removeObject(forKey: SavedCatalogItems.cacheOwnerKey)
            }
            let remoteIDs = try await firebase.fetchSavedCatalogItemIDs(
                expectedUserID: userID
            )
            guard SavedCatalogItems.isCurrentSession(
                expectedUserID: userID,
                activeUserID: AuthViewModel.shared.user?.uid,
                expectedGeneration: generation,
                currentGeneration: sessionGeneration
            ) else {
                return
            }
            itemIDs = remoteIDs
            loadedUserID = userID
            cacheOwnerUserID = userID
            persist()
            errorMessage = nil
        } catch {
            guard SavedCatalogItems.isCurrentSession(
                expectedUserID: userID,
                activeUserID: AuthViewModel.shared.user?.uid,
                expectedGeneration: generation,
                currentGeneration: sessionGeneration
            ) else {
                return
            }
            errorMessage = String(
                localized: "無法同步服務收藏：\(error.localizedDescription)"
            )
            CrashReporting.recordError(error, domain: "CatalogFavoritesStore.refresh")
        }
    }

    func setSaved(_ itemID: String, isSaved: Bool) async {
        let validOperation = isSaved
            ? SavedCatalogItems.isValidItemID(itemID)
            : SavedCatalogItems.isSafeStoredItemID(itemID)
        guard validOperation else {
            errorMessage = FirebaseError.invalidSavedCatalogItemID.localizedDescription
            return
        }
        guard !updatingItemIDs.contains(itemID) else { return }
        guard let userID = AuthViewModel.shared.user?.uid, !userID.isEmpty else {
            errorMessage = FirebaseError.authenticationRequired.localizedDescription
            return
        }

        if loadedUserID != userID {
            await refresh()
        }
        guard AuthViewModel.shared.user?.uid == userID else {
            return
        }

        // A write can still be safe after the initial read failed because the
        // server uses arrayUnion/arrayRemove. Bind the optimistic state to this
        // exact account before exposing or persisting it, and prevent a second
        // item from starting another refresh that could replace the first
        // in-flight optimistic mutation with an older server snapshot.
        cacheOwnerUserID = userID
        loadedUserID = userID

        let generation = sessionGeneration
        let previousIDs = itemIDs
        let nextIDs = SavedCatalogItems.setting(
            itemID,
            isSaved: isSaved,
            in: previousIDs
        )
        guard nextIDs != previousIDs else {
            if isSaved && !previousIDs.contains(itemID) {
                errorMessage = String(
                    localized: "最多可收藏 \(SavedCatalogItems.maximumCount) 項服務或保險。"
                )
            }
            return
        }

        itemIDs = nextIDs
        persist()
        updatingItemIDs.insert(itemID)
        defer { updatingItemIDs.remove(itemID) }

        do {
            try await firebase.setCatalogItemSaved(
                itemID,
                isSaved: isSaved,
                expectedUserID: userID
            )
            guard SavedCatalogItems.isCurrentSession(
                expectedUserID: userID,
                activeUserID: AuthViewModel.shared.user?.uid,
                expectedGeneration: generation,
                currentGeneration: sessionGeneration
            ) else {
                return
            }
            loadedUserID = userID
            cacheOwnerUserID = userID
            persist()
            errorMessage = nil
            Haptics.light()
        } catch {
            guard SavedCatalogItems.isCurrentSession(
                expectedUserID: userID,
                activeUserID: AuthViewModel.shared.user?.uid,
                expectedGeneration: generation,
                currentGeneration: sessionGeneration
            ) else {
                return
            }
            // Roll back only this item. Restoring the whole old snapshot would
            // erase a different item whose concurrent Firestore write succeeded.
            itemIDs = SavedCatalogItems.rollingBack(
                itemID,
                attemptedSave: isSaved,
                previousItemIDs: previousIDs,
                currentItemIDs: itemIDs
            )
            persist()
            errorMessage = String(
                localized: "無法更新服務收藏：\(error.localizedDescription)"
            )
            CrashReporting.recordError(error, domain: "CatalogFavoritesStore.setSaved")
        }
    }

    func clearLocalSession() {
        sessionGeneration &+= 1
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        activeRefreshID = nil
        itemIDs = []
        updatingItemIDs = []
        loadedUserID = nil
        cacheOwnerUserID = nil
        preparedUserID = nil
        isLoading = false
        errorMessage = nil
        defaults.removeObject(forKey: SavedCatalogItems.storageKey)
        defaults.removeObject(forKey: SavedCatalogItems.cacheOwnerKey)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func persist() {
        defaults.set(
            SavedCatalogItems.encode(itemIDs),
            forKey: SavedCatalogItems.storageKey
        )
        if let cacheOwnerUserID {
            defaults.set(cacheOwnerUserID, forKey: SavedCatalogItems.cacheOwnerKey)
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

struct CatalogFavoriteButton: View {
    let itemID: String
    let kind: SavedCatalogItemKind

    @ObservedObject private var auth = AuthViewModel.shared
    @ObservedObject private var favorites = CatalogFavoritesStore.shared
    @State private var showLogin = false
    @State private var desiredSavedAfterLogin: Bool?

    private var isSaved: Bool {
        auth.authState == .signedIn && favorites.contains(itemID)
    }

    private var alertTitle: String {
        kind == .service
            ? String(localized: "服務收藏")
            : String(localized: "保險入口收藏")
    }

    private var favoriteAccessibilityLabel: String {
        switch (kind, isSaved) {
        case (.service, false):
            String(localized: "將服務加入收藏")
        case (.service, true):
            String(localized: "從收藏移除服務")
        case (.insurance, false):
            String(localized: "將保險入口加入收藏")
        case (.insurance, true):
            String(localized: "從收藏移除保險入口")
        }
    }

    private var favoriteAccessibilityHint: String {
        auth.authState == .signedIn
            ? String(localized: "同步到你的 VetMap 帳戶")
            : String(localized: "登入後同步到你的 VetMap 帳戶")
    }

    var body: some View {
        Button {
            let desiredValue = !isSaved
            if auth.authState == .signedIn {
                Task {
                    await favorites.setSaved(itemID, isSaved: desiredValue)
                }
            } else {
                desiredSavedAfterLogin = desiredValue
                showLogin = true
            }
        } label: {
            ZStack {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .foregroundStyle(isSaved ? Color.red : Color.secondary)
                    .font(.title3)
                    .opacity(favorites.isUpdating(itemID) ? 0.25 : 1)

                if favorites.isUpdating(itemID) {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(
            favorites.isUpdating(itemID)
                || SavedCatalogItems.kind(for: itemID) != kind
        )
        .accessibilityLabel(Text(favoriteAccessibilityLabel))
        .accessibilityHint(Text(favoriteAccessibilityHint))
        .fullScreenCover(isPresented: $showLogin, onDismiss: {
            if auth.authState != .signedIn {
                desiredSavedAfterLogin = nil
            }
        }) {
            LoginView(authViewModel: auth)
        }
        .alert(
            alertTitle,
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
                desiredSavedAfterLogin = nil
                favorites.clearLocalSession()
                return
            }
            guard newState == .signedIn,
                  let desiredValue = desiredSavedAfterLogin else { return }
            desiredSavedAfterLogin = nil
            showLogin = false
            Task {
                await favorites.refresh(force: true)
                await favorites.setSaved(itemID, isSaved: desiredValue)
            }
        }
    }
}
