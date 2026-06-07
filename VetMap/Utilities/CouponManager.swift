import Foundation

struct Coupon: Identifiable, Codable {
    let id: String
    let clinicID: String
    let title: String
    let discount: String
    let expiryDate: Date
    let isActive: Bool
}

@MainActor
final class CouponManager: ObservableObject {
    @Published var coupons: [Coupon] = []
    
    func loadCoupons() {
        // TODO: Load from Firestore / partner API
        // Placeholder for partner clinic promotions
    }
}
