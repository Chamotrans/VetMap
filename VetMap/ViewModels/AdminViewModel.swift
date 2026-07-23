import Foundation

// MARK: - 管理員身分（Firestore role claim）
// 管理員身分來自 Firestore `users/{uid}` 文件的 `role` 欄位（== "admin"）。
// 寫入操作應由 Firestore 安全規則再次驗證 role == "admin"。
// DEBUG 模式另提供本機開關，方便在沒有真實後端時測試後台。

@MainActor
final class AdminViewModel: ObservableObject {
    static let shared = AdminViewModel()

    @Published private(set) var isAdmin = false
    @Published private(set) var isChecking = false

    #if DEBUG
    @Published var debugAdminOverride: Bool = UserDefaults.standard.bool(forKey: "debugAdminOverride") {
        didSet {
            UserDefaults.standard.set(debugAdminOverride, forKey: "debugAdminOverride")
            recompute()
        }
    }
    #endif

    private var firestoreRoleIsAdmin = false
    private var requestedRoleUID: String?

    init() {
        recompute()
    }

    /// 在登入狀態變化時呼叫，依 uid 重新查詢 Firestore 角色。
    func refresh(uid: String?) {
        guard let uid, !uid.isEmpty else {
            requestedRoleUID = nil
            firestoreRoleIsAdmin = false
            isChecking = false
            recompute()
            return
        }
        requestedRoleUID = uid
        isChecking = true
        Task {
            let role = await Self.fetchRole(uid: uid)
            guard requestedRoleUID == uid else { return }
            firestoreRoleIsAdmin = (role?.lowercased() == "admin")
            isChecking = false
            recompute()
        }
    }

    private func recompute() {
        #if DEBUG
        isAdmin = firestoreRoleIsAdmin || debugAdminOverride
        #else
        isAdmin = firestoreRoleIsAdmin
        #endif
    }

    private static func fetchRole(uid: String) async -> String? {
        #if canImport(FirebaseCore) && canImport(FirebaseFirestore)
        return await FirebaseService.shared.fetchUserRole(uid: uid)
        #else
        return nil
        #endif
    }
}
