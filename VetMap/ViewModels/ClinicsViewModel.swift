import Combine
import Foundation

@MainActor
@Observable
final class ClinicsViewModel {
    var filter = ClinicSearchFilter()
    private(set) var clinics: [VetClinic] = []
    private(set) var officialClinics: [OfficialClinicRecord] = []
    private(set) var officialManifest: OfficialClinicCatalogManifest?
    private(set) var storageError: String?
    private(set) var officialError: String?
    private(set) var pinnedIDs: Set<String> = []
    private(set) var removedIDs: Set<String> = []
    var isLoading = false
    var isLoadingOfficial = false
    var networkError: String?
    var officialQuery = ""
    var officialCity = "全部縣市"

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

    var officialCities: [String] {
        ["全部縣市"] + Set(officialClinics.map(\.city)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    var filteredOfficialClinics: [OfficialClinicRecord] {
        let tokens = officialQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        return officialClinics.filter { clinic in
            let matchesCity = officialCity == "全部縣市" || clinic.city == officialCity
            let haystack = [
                clinic.institutionName,
                clinic.address,
                clinic.city,
                clinic.phone,
                clinic.licenseNumber,
                clinic.licenseType,
                clinic.licenseStatus
            ].joined(separator: " ")
            return matchesCity && tokens.allSatisfy {
                haystack.localizedCaseInsensitiveContains($0)
            }
        }
    }

    var officialFilterDescription: String {
        var parts: [String] = []
        let query = officialQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            parts.append("「\(query)」")
        }
        if officialCity != "全部縣市" {
            parts.append(officialCity)
        }
        return parts.isEmpty ? "全部官方登記" : parts.joined(separator: "・")
    }

    func isPinned(_ clinicID: String) -> Bool {
        pinnedIDs.contains(clinicID)
    }

    func loadClinics() async {
        isLoading = true
        isLoadingOfficial = true
        networkError = nil
        officialError = nil
        defer {
            isLoading = false
            isLoadingOfficial = false
        }

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

        do {
            let catalog = try await firebase.fetchOfficialClinicCatalog()
            officialClinics = catalog.records
            officialManifest = catalog.manifest
            officialError = nil
        } catch {
            officialError = error.localizedDescription
            CrashReporting.recordError(
                error,
                domain: "ClinicsViewModel.loadOfficialClinicCatalog"
            )
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
