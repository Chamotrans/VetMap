import Foundation

enum Analytics {
    static func logEvent(_ name: String, parameters: [String: Any]? = nil) {
        #if DEBUG
        print("[Local analytics] \(name) \(parameters ?? [:])")
        #endif
    }

    // Pre-defined events
    static func clinicViewed(_ clinicName: String) {
        logEvent("clinic_viewed", parameters: ["clinic_name": clinicName])
    }
    static func reviewSubmitted(_ clinicName: String, rating: Int) {
        logEvent("review_submitted", parameters: ["clinic_name": clinicName, "rating": rating])
    }
    static func clinicAdded(_ clinicName: String) {
        logEvent("clinic_added", parameters: ["clinic_name": clinicName])
    }
    static func premiumPurchaseStarted(_ plan: String) {
        logEvent("premium_purchase_started", parameters: ["plan": plan])
    }
    static func premiumPurchased(_ plan: String) {
        logEvent("premium_purchased", parameters: ["plan": plan])
    }
    static func searchPerformed(_ query: String) {
        logEvent("search_performed", parameters: ["query": query])
    }
}
