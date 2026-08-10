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
    private(set) var availabilityNow = Date()
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
        observeAvailabilityClock()
        Task { await loadClinics() }
    }

    var filteredClinics: [VetClinic] {
        let base = filter.results(from: clinics, at: availabilityNow)
            .filter { !removedIDs.contains($0.id) }
        let pinned = base.filter { pinnedIDs.contains($0.id) }
        let rest = base.filter { !pinnedIDs.contains($0.id) }
        return pinned + rest
    }

    var duplicateCandidateClinics: [VetClinic] {
        ClinicDuplicateMatcher.duplicateCandidates(
            from: clinics,
            excludingRemovedClinicIDs: ModerationStore.shared.removedClinicIDs
        )
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

    func submitClinicForModeration(
        _ clinic: VetClinic
    ) async -> CommunitySubmissionResult {
        guard let uid = AuthViewModel.shared.user?.uid, !uid.isEmpty else {
            storageError = String(localized: "請先登入後再提交診所資料。")
            return .authenticationRequired
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
            return .submitted
        } catch FirebaseError.authenticationRequired {
            storageError = String(localized: "請先登入後再提交診所資料。")
            return .authenticationRequired
        } catch {
            storageError = error.localizedDescription
            return .failed(message: error.localizedDescription)
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

    private func observeAvailabilityClock() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                Task { @MainActor in
                    self?.availabilityNow = date
                }
            }
            .store(in: &cancellables)
    }
}
