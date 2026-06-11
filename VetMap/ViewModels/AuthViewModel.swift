import Foundation
import AuthenticationServices
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum AuthState {
    case loading
    case signedOut
    case signedIn
}

/// Lightweight user representation independent of FirebaseAuth.User
struct AppUser {
    let displayName: String?
    let email: String?

    #if canImport(FirebaseAuth)
    init(from firebaseUser: User) {
        self.displayName = firebaseUser.displayName
        self.email = firebaseUser.email
    }
    #endif

    init(displayName: String?, email: String?) {
        self.displayName = displayName
        self.email = email
    }
}

@MainActor
final class AuthViewModel: NSObject, ObservableObject {
    @Published var user: AppUser?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    /// Firebase SDK 已連結但可能未 configure（缺 GoogleService-Info.plist）。
    /// 未 configure 時呼叫 Auth.auth() 會 crash，必須先檢查。
    private var isFirebaseConfigured: Bool { FirebaseApp.app() != nil }

    override init() {
        super.init()
        guard isFirebaseConfigured else {
            // Firebase 未 configure — 退回本機模式（避免 Auth.auth() crash）
            authState = .signedOut
            DispatchQueue.main.async { [weak self] in
                self?.checkExistingAppleSignIn()
            }
            return
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user {
                    self?.user = AppUser(from: user)
                    self?.authState = .signedIn
                } else {
                    self?.checkExistingAppleSignIn()
                }
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    #else
    override init() {
        super.init()
        // Firebase SDK not linked — always signed out (local-only mode)
        authState = .signedOut
        DispatchQueue.main.async { [weak self] in
            self?.checkExistingAppleSignIn()
        }
    }
    #endif

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            errorMessage = nil  // 靜默 — 不顯示錯誤，UI 層已 disable email 登入
            return
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            if let currentUser = Auth.auth().currentUser { user = AppUser(from: currentUser) }
            authState = .signedIn
            Haptics.success()
        } catch {
            errorMessage = mapAuthError(error)
        }
        #else
        errorMessage = "Firebase SDK 尚未連結，無法註冊。"
        #endif
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        guard isFirebaseConfigured else {
            errorMessage = nil  // 靜默
            return
        }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = AppUser(from: result.user)
            authState = .signedIn
            Haptics.success()
        } catch {
            errorMessage = mapAuthError(error)
        }
        #else
        errorMessage = "Firebase SDK 尚未連結，無法登入。"
        #endif
    }

    func signOut() {
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
        KeychainService.deleteAppleUserIdentifier()
        user = nil
        authState = .signedOut
        errorMessage = nil
    }

    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func processAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple 登入憑證無效。"
                return
            }
            let userID = credential.user
            let displayName: String = {
                if let name = credential.fullName {
                    let given = name.givenName ?? ""
                    let family = name.familyName ?? ""
                    let full = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
                    if !full.isEmpty { return full }
                }
                return "Apple 用戶"
            }()
            let email = credential.email

            _ = KeychainService.saveAppleUserIdentifier(userID)
            user = AppUser(displayName: displayName, email: email)
            authState = .signedIn
            errorMessage = nil
            Haptics.success()
        case .failure(let error):
            let nsError = error as NSError
            switch nsError.code {
            case ASAuthorizationError.canceled.rawValue:
                errorMessage = nil
            case ASAuthorizationError.failed.rawValue:
                errorMessage = "Apple 登入失敗，請再試一次。"
            case ASAuthorizationError.invalidResponse.rawValue:
                errorMessage = "Apple 登入回應無效，請再試一次。"
            case ASAuthorizationError.notHandled.rawValue:
                errorMessage = "Apple 登入未處理，請再試一次。"
            default:
                errorMessage = error.localizedDescription
            }
        }
    }

    private func checkExistingAppleSignIn() {
        guard let userID = KeychainService.loadAppleUserIdentifier() else { return }
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userID) { [weak self] state, error in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .authorized:
                    self.user = AppUser(displayName: "Apple 用戶", email: nil)
                    self.authState = .signedIn
                case .revoked, .notFound:
                    KeychainService.deleteAppleUserIdentifier()
                case .transferred:
                    KeychainService.deleteAppleUserIdentifier()
                @unknown default:
                    break
                }
            }
        }
    }

    #if canImport(FirebaseAuth)
    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode(rawValue: nsError.code) else {
            return "發生未知錯誤，請再試一次。"
        }
        switch code {
        case .wrongPassword:
            return "密碼錯誤"
        case .userNotFound:
            return "帳號不存在"
        case .networkError:
            return "網絡錯誤，請檢查連線"
        case .invalidEmail:
            return "電子郵件格式不正確"
        case .weakPassword:
            return "密碼強度不足，請至少使用6個字元"
        case .emailAlreadyInUse:
            return "此電子郵件已被註冊"
        case .tooManyRequests:
            return "請求過於頻繁，請稍後再試"
        default:
            return error.localizedDescription
        }
    }
    #endif
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthViewModel: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        processAppleSignIn(result: .success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        processAppleSignIn(result: .failure(error))
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthViewModel: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
