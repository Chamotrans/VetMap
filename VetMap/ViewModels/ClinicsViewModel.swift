import Combine
import Foundation

@MainActor
final class ClinicsViewModel: ObservableObject {
    @Published var filter = ClinicSearchFilter()
    @Published private(set) var clinics: [VetClinic] = []
    @Published private(set) var storageError: String?
    @Published var isLoading = false
    @Published var networkError: String?

    private let repository: MockClinicRepository
    private var cancellables: Set<AnyCancellable> = []

    init(repository: MockClinicRepository = MockClinicRepository()) {
        self.repository = repository
        observeRepositoryChanges()
        loadClinics()
    }

    var filteredClinics: [VetClinic] {
        filter.results(from: clinics)
    }

    func loadClinics() {
        isLoading = true
        networkError = nil
        clinics = repository.fetchClinics()
        isLoading = false
    }

    func retryLoad() {
        loadClinics()
    }

    func addClinic(_ clinic: VetClinic) {
        do {
            try repository.addClinic(clinic)
            clinics = repository.fetchClinics()
            storageError = nil
        } catch {
            storageError = "診所已加入目前列表，但暫時無法儲存到本機。"
            CrashReporting.recordError(error, domain: "ClinicsViewModel")
            clinics.append(clinic)
        }

        filter = ClinicSearchFilter()
    }

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetClinicRepositoryDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadClinics()
                }
            }
            .store(in: &cancellables)
    }
}
