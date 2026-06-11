import Foundation

protocol ClinicRepositoryProtocol {
    func fetchClinics() async throws -> [VetClinic]
    func addClinic(_ clinic: VetClinic) async throws
    func searchClinics(query: String) async throws -> [VetClinic]
}

struct ClinicRepository: ClinicRepositoryProtocol {
    #if canImport(Firebase)
    private let firebaseService: FirebaseService?
    #endif
    private let localRepository: MockClinicRepository

    init(localRepository: MockClinicRepository = MockClinicRepository()) {
        #if canImport(Firebase)
        self.firebaseService = FirebaseService.shared
        #else
        #endif
        self.localRepository = localRepository
    }

    func fetchClinics() async throws -> [VetClinic] {
        #if canImport(Firebase)
        if let firebaseService {
            do {
                return try await firebaseService.fetchClinics()
            } catch {
                return localRepository.fetchClinics()
            }
        }
        #endif
        return localRepository.fetchClinics()
    }

    func addClinic(_ clinic: VetClinic) async throws {
        // 本機為真實來源（source of truth）；Firebase 為盡力同步（best-effort）。
        // 本機儲存失敗才是真錯誤；Firebase 同步失敗只記錄，不影響呼叫者。
        try localRepository.addClinic(clinic)
        #if canImport(Firebase)
        if let firebaseService {
            do {
                try await firebaseService.addClinic(clinic)
            } catch {
                CrashReporting.recordError(error, domain: "ClinicRepository.sync")
            }
        }
        #endif
    }

    func searchClinics(query: String) async throws -> [VetClinic] {
        #if canImport(Firebase)
        if let firebaseService {
            do {
                return try await firebaseService.searchClinics(query: query)
            } catch {
                return localSearch(query: query)
            }
        }
        #endif
        return localSearch(query: query)
    }

    private func localSearch(query: String) -> [VetClinic] {
        let clinics = localRepository.fetchClinics()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return clinics }

        let lowercased = trimmed.lowercased()
        return clinics.filter { clinic in
            clinic.name.lowercased().contains(lowercased) ||
            clinic.address.lowercased().contains(lowercased) ||
            clinic.tags.contains(where: { $0.lowercased().contains(lowercased) }) ||
            clinic.services.contains(where: { $0.lowercased().contains(lowercased) })
        }
    }
}
