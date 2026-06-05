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
        #if canImport(Firebase)
        if let firebaseService {
            var firebaseFailed = false
            do {
                try await firebaseService.addClinic(clinic)
            } catch {
                firebaseFailed = true
            }
            try localRepository.addClinic(clinic)
            if firebaseFailed {
                throw FirebaseError.notConfigured
            }
            return
        }
        #endif
        try localRepository.addClinic(clinic)
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
