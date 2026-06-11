// When Firebase SDK is linked via SPM, FirebaseService provides Firestore-backed CRUD.
// Without Firebase, the app uses local JSON persistence via Mock*Repository classes.
import Foundation

#if canImport(Firebase) && canImport(FirebaseFirestore)
import Firebase
import FirebaseFirestore

final class FirebaseService {
    static let shared = FirebaseService()

    private var isAvailable: Bool { FirebaseApp.app() != nil }

    private var firestore: Firestore? {
        guard isAvailable else { return nil }
        return Firestore.firestore()
    }

    private let encoder: Firestore.Encoder = {
        let encoder = Firestore.Encoder()
        encoder.dateEncodingStrategy = .timestamp
        return encoder
    }()

    private let decoder: Firestore.Decoder = {
        let decoder = Firestore.Decoder()
        decoder.dateDecodingStrategy = .timestamp
        return decoder
    }()

    // MARK: - Clinics

    func fetchClinics() async throws -> [VetClinic] {
        let db = try resolveFirestore()
        let snapshot = try await db.collection("clinics").getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: VetClinic.self) }
    }

    func addClinic(_ clinic: VetClinic) async throws {
        let db = try resolveFirestore()
        let data = try encoder.encode(clinic)
        try await db.collection("clinics").document(clinic.id).setData(data)
    }

    func searchClinics(query: String) async throws -> [VetClinic] {
        _ = try resolveFirestore()
        let clinics = try await fetchClinics()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return clinics
        }

        let lowercased = query.lowercased()
        return clinics.filter { clinic in
            clinic.name.lowercased().contains(lowercased) ||
            clinic.address.lowercased().contains(lowercased) ||
            clinic.tags.contains(where: { $0.lowercased().contains(lowercased) }) ||
            clinic.services.contains(where: { $0.lowercased().contains(lowercased) })
        }
    }

    // MARK: - Reviews

    func fetchReviews(for clinicId: String) async throws -> [Review] {
        let db = try resolveFirestore()
        let snapshot = try await db.collection("reviews")
            .whereField("clinicId", isEqualTo: clinicId)
            .getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: Review.self) }
    }

    func addReview(_ review: Review) async throws {
        let db = try resolveFirestore()
        let data = try encoder.encode(review)
        try await db.collection("reviews").document(review.id).setData(data)
    }

    // MARK: - Quotes

    func fetchQuotes(for clinicId: String) async throws -> [Quote] {
        let db = try resolveFirestore()
        let snapshot = try await db.collection("quotes")
            .whereField("clinicId", isEqualTo: clinicId)
            .getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: Quote.self) }
    }

    func addQuote(_ quote: Quote) async throws {
        let db = try resolveFirestore()
        let data = try encoder.encode(quote)
        try await db.collection("quotes").document(quote.id).setData(data)
    }

    // MARK: - Products

    func fetchProducts(category: String?) async throws -> [PetProduct] {
        let db = try resolveFirestore()
        let query: Query
        if let category {
            query = db.collection("products").whereField("category", isEqualTo: category)
        } else {
            query = db.collection("products")
        }
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: PetProduct.self) }
    }

    // MARK: - Insurances

    func fetchInsurances() async throws -> [Insurance] {
        let db = try resolveFirestore()
        let snapshot = try await db.collection("insurances").getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: Insurance.self) }
    }

    // MARK: - Helpers

    private func resolveFirestore() throws -> Firestore {
        guard let db = firestore else {
            CrashReporting.log("Firestore not configured")
            throw FirebaseError.notConfigured
        }
        return db
    }

    private func decodeDocument<T: Decodable>(_ document: DocumentSnapshot, as type: T.Type) throws -> T {
        do {
            return try document.data(as: type)
        } catch {
            throw FirebaseError.decodingFailed(error)
        }
    }
}
#endif

// FirebaseError is always available (used by ClinicRepository, CommunityRepository)
enum FirebaseError: Error {
    case notConfigured
    case documentNotFound(String)
    case encodingFailed(Error)
    case decodingFailed(Error)
}

extension FirebaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firebase 尚未設定，使用本機資料。"
        case .documentNotFound(let id):
            return "找不到文件：\(id)"
        case .encodingFailed(let error):
            return "資料編碼失敗：\(error.localizedDescription)"
        case .decodingFailed(let error):
            return "資料解碼失敗：\(error.localizedDescription)"
        }
    }
}
