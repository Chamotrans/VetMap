import Combine
import Foundation

@MainActor
final class ClinicsViewModel: ObservableObject {
    @Published var filter = ClinicSearchFilter()
    @Published private(set) var clinics: [VetClinic] = []
    @Published private(set) var storageError: String?

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
        clinics = repository.fetchClinics()
    }

    func addClinic(_ clinic: VetClinic) {
        do {
            try repository.addClinic(clinic)
            clinics = repository.fetchClinics()
            storageError = nil
        } catch {
            storageError = "診所已加入目前列表，但暫時無法儲存到本機。"
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
