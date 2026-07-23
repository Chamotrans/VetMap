import Foundation
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

enum CrashReporting {
    static func log(_ message: String) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log(message)
        #endif
        print("[Crashlytics] \(message)")
    }

    static func recordError(_ error: Error, domain: String = "VetMap") {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().record(error: error)
        #endif
        print("[Crashlytics][\(domain)] Error: \(error.localizedDescription)")
    }
}
