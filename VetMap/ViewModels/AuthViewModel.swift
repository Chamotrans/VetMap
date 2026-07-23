import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

enum AuthState: Equatable {
    case loading
    case signedOut
    case signedIn
}

enum AccountAuthProvider {
    case email
    case apple
    case unknown

    var displayName: String {
        switch self {
        case .email:
            return "電子郵件及密碼"
        case .apple:
            return "使用 Apple 登入"
        case .unknown:
            return "其他登入方式"
        }
    }
}

enum AppleAuthorizationPurpose {
    case signIn
    case deleteAccount
}

/// Lightweight user representation independent of FirebaseAuth.User.
struct AppUser {
    let displayName: String?
    let email: String?
    let uid: String?
    let providerIDs: [String]

    #if canImport(FirebaseAuth)
    init(from firebaseUser: User) {
        displayName = firebaseUser.displayName
        email = firebaseUser.email
        uid = firebaseUser.uid
        providerIDs = firebaseUser.providerData.map(\.providerID)
    }
    #endif

    init(
        displayName: String?,
        email: String?,
        uid: String? = nil,
        providerIDs: [String] = []
    ) {
        self.displayName = displayName
        self.email = email
        self.uid = uid
        self.providerIDs = providerIDs
    }
}

@MainActor
final class AuthViewModel: NSObject, ObservableObject {
    /// Production UI must use this instance so every tab and submission shares
    /// the same Firebase Auth session. The internal initializer remains usable
    /// by isolated unit tests.
    static let shared = AuthViewModel()

    @Published private(set) var user: AppUser?
    @Published private(set) var authState: AuthState = .loading
    @Published var errorMessage: String?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var isDeletingAccount = false

    private var currentNonce: String?
    private var pendingApplePurpose: AppleAuthorizationPurpose?
    private var appleCredentialRevokedObserver: NSObjectProtocol?

    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var syncedProfileUIDs = Set<String>()
    #endif

    private var isFirebaseConfigured: Bool {
        #if canImport(FirebaseCore)
        FirebaseApp.app() != nil
        #else
        false
        #endif
    }

    var accountProvider: AccountAuthProvider {
        let providerIDs = user?.providerIDs ?? []
        if providerIDs.contains("apple.com") {
            return .apple
        }
        if providerIDs.contains("password") {
            return .email
        }
        return .unknown
    }

    override init() {
        super.init()

        appleCredentialRevokedObserver = NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.verifyStoredAppleCredentialState()
            }
        }

        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            authState = .signedOut
            return
        }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let firebaseUser else {
                    user = nil
                    authState = .signedOut
                    return
                }

                user = AppUser(from: firebaseUser)
                verifyStoredAppleCredentialState()
                await ensureUserProfile(for: firebaseUser)
                guard Auth.auth().currentUser?.uid == firebaseUser.uid else { return }
                authState = .signedIn
            }
        }
        #else
        authState = .signedOut
        #endif
    }

    deinit {
        if let appleCredentialRevokedObserver {
            NotificationCenter.default.removeObserver(appleCredentialRevokedObserver)
        }

        #if canImport(FirebaseAuth)
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
        #endif
    }

    // MARK: - Email authentication

    func signUp(email: String, password: String, displayName: String) async {
        clearError()

        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let result = try await Auth.auth().createUser(
                withEmail: normalizedEmail,
                password: password
            )

            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = normalizedName
            try await changeRequest.commitChanges()
            try await writeUserProfile(
                for: result.user,
                fallbackDisplayName: normalizedName,
                isNewUser: true
            )
            guard Auth.auth().currentUser?.uid == result.user.uid else { return }

            user = AppUser(from: result.user)
            authState = .signedIn
            Haptics.success()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
        #else
        errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
        #endif
    }

    func signIn(email: String, password: String) async {
        clearError()

        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let result = try await Auth.auth().signIn(
                withEmail: normalizedEmail,
                password: password
            )
            await ensureUserProfile(for: result.user)
            guard Auth.auth().currentUser?.uid == result.user.uid else { return }
            user = AppUser(from: result.user)
            authState = .signedIn
            Haptics.success()
        } catch {
            errorMessage = userFacingMessage(for: error)
        }
        #else
        errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
        #endif
    }

    func signOut() {
        clearError()

        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            do {
                try Auth.auth().signOut()
            } catch {
                errorMessage = "登出失敗，請再試一次。"
                return
            }
        }
        #endif

        clearSessionState()
    }

    // MARK: - Sign in with Apple

    /// Configures Apple's request with a cryptographically secure, one-use
    /// nonce. The raw nonce is retained only until the matching callback.
    func prepareAppleRequest(
        _ request: ASAuthorizationAppleIDRequest,
        purpose: AppleAuthorizationPurpose
    ) {
        clearError()

        do {
            let nonce = try Self.randomNonceString()
            currentNonce = nonce
            pendingApplePurpose = purpose
            switch purpose {
            case .signIn:
                isAuthenticating = true
            case .deleteAccount:
                isDeletingAccount = true
            }
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)
        } catch {
            currentNonce = nil
            pendingApplePurpose = nil
            isAuthenticating = false
            isDeletingAccount = false
            errorMessage = userFacingMessage(for: error)
        }
    }

    /// Convenience entry point for non-SwiftUI callers.
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        prepareAppleRequest(request, purpose: .signIn)
        guard currentNonce != nil else { return }

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func processAppleAuthorization(
        result: Result<ASAuthorization, Error>,
        purpose: AppleAuthorizationPurpose
    ) {
        switch result {
        case .success(let authorization):
            guard pendingApplePurpose == purpose,
                  let nonce = currentNonce,
                  let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                resetPendingAppleAuthorization()
                isAuthenticating = false
                isDeletingAccount = false
                errorMessage = "Apple 登入憑證無效，請重新嘗試。"
                return
            }

            resetPendingAppleAuthorization()
            Task {
                await handleAppleCredential(
                    appleCredential,
                    rawNonce: nonce,
                    purpose: purpose
                )
            }

        case .failure(let error):
            resetPendingAppleAuthorization()
            isAuthenticating = false
            isDeletingAccount = false
            handleAppleAuthorizationError(error)
        }
    }

    // MARK: - Account deletion

    /// Password accounts must reauthenticate immediately before the destructive
    /// operation. The backend callable purges user-owned data using request.auth
    /// and must succeed before the Firebase Auth user is deleted.
    @discardableResult
    func deleteEmailAccount(password: String) async -> Bool {
        clearError()

        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured,
              let firebaseUser = Auth.auth().currentUser,
              let email = firebaseUser.email,
              !password.isEmpty else {
            errorMessage = "請輸入目前密碼以確認刪除帳戶。"
            return false
        }

        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await firebaseUser.reauthenticate(with: credential)
            _ = try await firebaseUser.getIDTokenResult(forcingRefresh: true)
            try await purgeUserData()
            try await firebaseUser.delete()
            finishAccountDeletion()
            return true
        } catch {
            errorMessage = userFacingMessage(for: error)
            return false
        }
        #else
        errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
        return false
        #endif
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Apple handling

    private func handleAppleCredential(
        _ appleCredential: ASAuthorizationAppleIDCredential,
        rawNonce: String,
        purpose: AppleAuthorizationPurpose
    ) async {
        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            isAuthenticating = false
            isDeletingAccount = false
            errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
            return
        }

        guard let identityToken = appleCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            isAuthenticating = false
            isDeletingAccount = false
            errorMessage = "Apple 未有提供有效的身份憑證，請重新嘗試。"
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleCredential.fullName
        )

        switch purpose {
        case .signIn:
            isAuthenticating = true
            defer { isAuthenticating = false }

            do {
                let result = try await Auth.auth().signIn(with: firebaseCredential)
                _ = KeychainService.saveAppleUserIdentifier(appleCredential.user)
                user = AppUser(from: result.user)
                try await writeUserProfile(
                    for: result.user,
                    fallbackDisplayName: formattedName(from: appleCredential.fullName),
                    isNewUser: result.additionalUserInfo?.isNewUser == true
                )
                guard Auth.auth().currentUser?.uid == result.user.uid else { return }
                authState = .signedIn
                Haptics.success()
            } catch {
                errorMessage = userFacingMessage(for: error)
            }

        case .deleteAccount:
            guard let authorizationCode = appleCredential.authorizationCode,
                  let authorizationCodeString = String(data: authorizationCode, encoding: .utf8),
                  let firebaseUser = Auth.auth().currentUser else {
                isDeletingAccount = false
                errorMessage = "Apple 未有提供刪除帳戶所需的授權碼，請重新嘗試。"
                return
            }

            isDeletingAccount = true
            defer { isDeletingAccount = false }

            do {
                try await firebaseUser.reauthenticate(with: firebaseCredential)
                _ = try await firebaseUser.getIDTokenResult(forcingRefresh: true)
                try await purgeUserData()
                try await Auth.auth().revokeToken(
                    withAuthorizationCode: authorizationCodeString
                )
                try await firebaseUser.delete()
                finishAccountDeletion()
            } catch {
                errorMessage = userFacingMessage(for: error)
            }
        }
        #else
        isAuthenticating = false
        isDeletingAccount = false
        errorMessage = AuthOperationError.firebaseUnavailable.localizedDescription
        #endif
    }

    private func handleAppleAuthorizationError(_ error: Error) {
        let nsError = error as NSError
        switch nsError.code {
        case ASAuthorizationError.canceled.rawValue:
            errorMessage = nil
        case ASAuthorizationError.failed.rawValue:
            errorMessage = "Apple 登入失敗，請再試一次。"
        case ASAuthorizationError.invalidResponse.rawValue:
            errorMessage = "Apple 登入回應無效，請再試一次。"
        case ASAuthorizationError.notHandled.rawValue:
            errorMessage = "Apple 登入未能完成，請再試一次。"
        case ASAuthorizationError.notInteractive.rawValue:
            errorMessage = "Apple 登入暫時無法互動，請再試一次。"
        default:
            errorMessage = "Apple 登入失敗，請再試一次。"
        }
    }

    private func resetPendingAppleAuthorization() {
        currentNonce = nil
        pendingApplePurpose = nil
    }

    private func verifyStoredAppleCredentialState() {
        guard let appleUserIdentifier = KeychainService.loadAppleUserIdentifier() else {
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(
            forUserID: appleUserIdentifier
        ) { [weak self] credentialState, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    CrashReporting.recordError(
                        error,
                        domain: "AuthViewModel.appleCredentialState"
                    )
                    return
                }

                switch credentialState {
                case .authorized:
                    break
                case .revoked, .notFound, .transferred:
                    forceSignOutAfterAppleCredentialRevocation()
                @unknown default:
                    forceSignOutAfterAppleCredentialRevocation()
                }
            }
        }
    }

    private func forceSignOutAfterAppleCredentialRevocation() {
        #if canImport(FirebaseAuth)
        if isFirebaseConfigured {
            do {
                try Auth.auth().signOut()
            } catch {
                CrashReporting.recordError(
                    error,
                    domain: "AuthViewModel.appleCredentialRevocationSignOut"
                )
            }
        }
        #endif

        clearSessionState()
        errorMessage = "Apple 登入授權已失效，請重新登入。"
    }

    // MARK: - User profile

    #if canImport(FirebaseAuth)
    private func ensureUserProfile(for firebaseUser: User) async {
        guard !syncedProfileUIDs.contains(firebaseUser.uid) else { return }

        do {
            try await writeUserProfile(
                for: firebaseUser,
                fallbackDisplayName: nil,
                isNewUser: false
            )
            syncedProfileUIDs.insert(firebaseUser.uid)
        } catch {
            CrashReporting.recordError(error, domain: "AuthViewModel.ensureUserProfile")
        }
    }

    private func writeUserProfile(
        for firebaseUser: User,
        fallbackDisplayName: String?,
        isNewUser: Bool
    ) async throws {
        #if canImport(FirebaseFirestore)
        let reference = Firestore.firestore()
            .collection("users")
            .document(firebaseUser.uid)
        let shouldInitialize: Bool
        if isNewUser {
            shouldInitialize = true
        } else {
            let existingProfile = try await reference.getDocument()
            shouldInitialize = !existingProfile.exists
        }

        var profile: [String: Any] = [
            "uid": firebaseUser.uid,
            "displayName": firebaseUser.displayName
                ?? fallbackDisplayName
                ?? "VetMap 用戶",
            "email": firebaseUser.email ?? "",
            "providerIDs": firebaseUser.providerData.map(\.providerID),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if shouldInitialize {
            profile["createdAt"] = FieldValue.serverTimestamp()
            profile["isPremium"] = false
            profile["favoriteClinics"] = [String]()
            profile["savedProducts"] = [String]()
        }

        try await reference.setData(profile, merge: true)
        syncedProfileUIDs.insert(firebaseUser.uid)
        #else
        throw AuthOperationError.firestoreUnavailable
        #endif
    }
    #endif

    // MARK: - Destructive operation helpers

    private func purgeUserData() async throws {
        #if canImport(FirebaseFunctions)
        let callable = Functions.functions(region: "asia-east1")
            .httpsCallable("purgeUserData")
        _ = try await callable.call(["requestVersion": 1])
        #else
        throw AuthOperationError.functionsUnavailable
        #endif
    }

    private func finishAccountDeletion() {
        clearLocalAccountData()
        user = nil
        authState = .signedOut
        errorMessage = nil
        Haptics.success()
    }

    private func clearSessionState() {
        KeychainService.deleteAppleUserIdentifier()
        user = nil
        authState = .signedOut
        isAuthenticating = false
        isDeletingAccount = false
    }

    /// Removes account-owned caches and drafts after both backend purge and
    /// Firebase Auth deletion have completed. Onboarding and display preferences
    /// intentionally remain device settings.
    private func clearLocalAccountData() {
        KeychainService.deleteAppleUserIdentifier()

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "favorites")
        defaults.removeObject(forKey: "debugAdminOverride")

        let fileManager = FileManager.default
        if let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            try? fileManager.removeItem(
                at: applicationSupport.appending(path: "VetMap", directoryHint: .isDirectory)
            )
        }

        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(
                at: caches.appending(path: "review-photos", directoryHint: .isDirectory)
            )
        }
    }

    // MARK: - Error and crypto helpers

    #if canImport(FirebaseAuth)
    private func userFacingMessage(for error: Error) -> String {
        if let operationError = error as? AuthOperationError {
            return operationError.localizedDescription
        }

        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .wrongPassword, .invalidCredential:
            return "電子郵件或密碼不正確。"
        case .userNotFound:
            return "找不到這個帳戶。"
        case .networkError:
            return "網絡錯誤，請檢查連線後再試。"
        case .invalidEmail:
            return "電子郵件格式不正確。"
        case .weakPassword:
            return "密碼強度不足，請至少使用 6 個字元。"
        case .emailAlreadyInUse:
            return "此電子郵件已被註冊。"
        case .tooManyRequests:
            return "請求過於頻繁，請稍後再試。"
        case .requiresRecentLogin:
            return "基於安全理由，請重新登入後再刪除帳戶。"
        case .missingOrInvalidNonce:
            return "Apple 安全驗證失敗，請重新嘗試。"
        default:
            return error.localizedDescription
        }
    }
    #else
    private func userFacingMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
    #endif

    private func formattedName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let value = formatter.string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else { throw AuthOperationError.nonceGenerationFailed }

        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(
            kSecRandomDefault,
            randomBytes.count,
            &randomBytes
        )
        guard status == errSecSuccess else {
            throw AuthOperationError.nonceGenerationFailed
        }

        let characters = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        return String(randomBytes.map { characters[Int($0) % characters.count] })
    }
}

private enum AuthOperationError: LocalizedError {
    case firebaseUnavailable
    case firestoreUnavailable
    case functionsUnavailable
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "登入服務暫時未能使用，請稍後再試。"
        case .firestoreUnavailable:
            return "未能建立用戶資料，請稍後再試。"
        case .functionsUnavailable:
            return "刪除帳戶服務暫時未能使用，帳戶尚未刪除。"
        case .nonceGenerationFailed:
            return "未能建立安全登入請求，請重新嘗試。"
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        processAppleAuthorization(
            result: .success(authorization),
            purpose: pendingApplePurpose ?? .signIn
        )
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        processAppleAuthorization(
            result: .failure(error),
            purpose: pendingApplePurpose ?? .signIn
        )
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
