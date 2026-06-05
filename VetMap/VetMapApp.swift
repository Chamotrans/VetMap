import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

@main
struct VetMapApp: App {
    init() {
        configureFirebase()
        RatingPrompt.incrementLaunchCount()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    RatingPrompt.requestReviewIfAppropriate()
                }
        }
    }

    private func configureFirebase() {
        #if canImport(FirebaseCore)
        guard let configPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("Firebase: GoogleService-Info.plist not found — 使用本機資料。")
            return
        }

        guard let options = FirebaseOptions(contentsOfFile: configPath) else {
            print("Firebase: failed to parse GoogleService-Info.plist — 使用本機資料。")
            return
        }

        FirebaseApp.configure(options: options)
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        print("VetMap v\(appVersion) (\(buildNumber)) — Firebase configured")
        #else
        print("Firebase SDK not linked — 使用本機資料。")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        print("VetMap v\(appVersion) (\(buildNumber)) — cold start (local mode)")
        #endif
    }
}
