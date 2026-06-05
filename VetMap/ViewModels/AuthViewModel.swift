import Foundation
#if canImport(FirebaseAuth)
import FirebaseAuth
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
final class AuthViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var authState: AuthState = .loading
    @Published var errorMessage: String?

    #if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user {
                    self?.user = AppUser(from: user)
                    self?.authState = .signedIn
                } else {
                    self?.user = nil
                    self?.authState = .signedOut
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
    init() {
        // Firebase SDK not linked — always signed out (local-only mode)
        authState = .signedOut
    }
    #endif

    func signUp(email: String, password: String, displayName: String) async {
        errorMessage = nil
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = displayName
            try await changeRequest.commitChanges()
            user = AppUser(from: Auth.auth().currentUser!)
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
        do {
            try Auth.auth().signOut()
            user = nil
            authState = .signedOut
            errorMessage = nil
        } catch {
            errorMessage = "登出失敗，請再試一次。"
        }
        #else
        user = nil
        authState = .signedOut
        errorMessage = nil
        #endif
    }

    func signInWithApple() {
        // TODO: Implement Apple Sign In with ASAuthorizationController
    }

    #if canImport(FirebaseAuth)
    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        guard let code = AuthErrorCode.Code(rawValue: nsError.code) else {
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
