import SwiftUI

@main
struct VetMapApp: App {
    init() {
        configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func configureFirebase() {
        #if canImport(Firebase)
        #if targetEnvironment(simulator)
        print("Firebase: running on simulator — skipping FirebaseApp.configure(). 使用本機資料。")
        #else
        guard let configPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("Firebase: GoogleService-Info.plist not found — 使用本機資料。")
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: configPath) else {
            print("Firebase: failed to parse GoogleService-Info.plist — 使用本機資料。")
            return
        }

        FirebaseApp.configure(options: options)
        #endif
        #else
        print("Firebase SDK not linked — 使用本機資料。")
        #endif
    }
}
