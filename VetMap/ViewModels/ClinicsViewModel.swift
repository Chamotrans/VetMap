import Combine
import Foundation

@MainActor
final class ClinicsViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case verified = "已驗證"
        case catFriendly = "貓友善"
        case affordable = "價格中等"

        var id: String { rawValue }
    }

    @Published var searchText = ""
    @Published var selectedFilter: Filter = .all
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
        clinics
            .filter(matchesFilter)
            .filter(matchesSearch)
            .sorted { lhs, rhs in
                if lhs.verified != rhs.verified {
                    return lhs.verified && !rhs.verified
                }

                return lhs.avgRating > rhs.avgRating
            }
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

        selectedFilter = .all
        searchText = ""
    }

    private func matchesFilter(_ clinic: VetClinic) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .verified:
            return clinic.verified
        case .catFriendly:
            return clinic.tags.contains("貓友善")
        case .affordable:
            return clinic.priceLevel <= 2
        }
    }

    private func matchesSearch(_ clinic: VetClinic) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let haystack = [
            clinic.name,
            clinic.address,
            clinic.phone,
            clinic.services.joined(separator: " "),
            clinic.tags.joined(separator: " ")
        ].joined(separator: " ")

        return haystack.localizedCaseInsensitiveContains(query)
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
