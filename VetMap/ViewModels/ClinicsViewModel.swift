import Combine
import Foundation

@MainActor
@Observable
final class ClinicsViewModel {
    var filter = ClinicSearchFilter()
    private(set) var clinics: [VetClinic] = []
    private(set) var storageError: String?
    private(set) var pinnedIDs: Set<String> = []
    private(set) var removedIDs: Set<String> = []
    var isLoading = false
    var networkError: String?

    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init(
        repository _: MockClinicRepository = MockClinicRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.firebase = firebase
        observeModerationChanges()
        Task { await loadClinics() }
    }

    var filteredClinics: [VetClinic] {
        let base = filter.results(from: clinics).filter { !removedIDs.contains($0.id) }
        let pinned = base.filter { pinnedIDs.contains($0.id) }
        let rest = base.filter { !pinnedIDs.contains($0.id) }
        return pinned + rest
    }

    func isPinned(_ clinicID: String) -> Bool {
        pinnedIDs.contains(clinicID)
    }

    func loadClinics() async {
        isLoading = true
        networkError = nil
        defer { isLoading = false }

        await ModerationStore.shared.refreshPublicState()
        refreshModerationState()

        do {
            clinics = try await firebase.fetchClinics()
            storageError = nil
        } catch {
            networkError = "雲端診所資料暫時無法載入：\(error.localizedDescription)"
            storageError = networkError
            CrashReporting.recordError(error, domain: "ClinicsViewModel.loadClinics")
        }
    }

    func retryLoad() async {
        await loadClinics()
    }

    func submitClinicForModeration(_ clinic: VetClinic) async -> Bool {
        guard let uid = AuthViewModel.shared.user?.uid, !uid.isEmpty else {
            storageError = "請先登入後再提交診所資料。"
            return false
        }

        do {
            try ContentSafety.validate([
                clinic.name,
                clinic.address,
                clinic.phone,
                clinic.services.joined(separator: " "),
                clinic.tags.joined(separator: " ")
            ])
            try await ModerationStore.shared.submitClinic(clinic)
            storageError = nil
            filter = ClinicSearchFilter()
            Haptics.success()
            return true
        } catch {
            storageError = error.localizedDescription
            return false
        }
    }

    private func refreshModerationState() {
        pinnedIDs = ModerationStore.shared.pinnedClinicIDs
        removedIDs = ModerationStore.shared.removedClinicIDs
    }

    private func observeModerationChanges() {
        NotificationCenter.default.publisher(for: .vetModerationDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadClinics()
                }
            }
            .store(in: &cancellables)
    }

}
