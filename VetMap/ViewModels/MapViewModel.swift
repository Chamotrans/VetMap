import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
@Observable
final class MapViewModel {
    private(set) var clinics: [VetClinic] = []
    var selectedClinicID: String?
    var cameraPosition: MapCameraPosition
    var filter = ClinicSearchFilter() {
        didSet {
            syncSelectionWithFilteredClinics(shouldFocus: true)
        }
    }
    var isLoading = false
    var networkError: String?

    private let repository: MockClinicRepository
    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init(
        repository: MockClinicRepository = MockClinicRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.repository = repository
        self.firebase = firebase
        self.cameraPosition = .region(Self.defaultRegion)
        self.clinics = repository.fetchClinics()
        observeRepositoryChanges()
        loadClinics()
    }

    var selectedClinic: VetClinic? {
        guard let selectedClinicID else { return filteredClinics.first }
        return filteredClinics.first { $0.id == selectedClinicID }
    }

    var filteredClinics: [VetClinic] {
        filter.results(from: clinics).filter {
            !ModerationStore.shared.removedClinicIDs.contains($0.id)
        }
    }

    func loadClinics() {
        Task { await loadClinics(focusingOn: nil) }
    }

    func retryLoad() {
        loadClinics()
    }

    private func loadClinics(focusingOn clinicID: String?) async {
        isLoading = true
        networkError = nil
        let previousSelectedClinicID = selectedClinicID
        let seeds = repository.fetchClinics()
        await ModerationStore.shared.refreshPublicState()
        do {
            let cloud = try await firebase.fetchClinics()
            let cloudIDs = Set(cloud.map(\.id))
            clinics = cloud + seeds.filter { !cloudIDs.contains($0.id) }
        } catch {
            clinics = seeds
            networkError = "雲端診所資料暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "MapViewModel.loadClinics")
        }

        if let clinicID, let clinic = filteredClinics.first(where: { $0.id == clinicID }) {
            focus(on: clinic)
        } else if let previousSelectedClinicID, filteredClinics.contains(where: { $0.id == previousSelectedClinicID }) {
            selectedClinicID = previousSelectedClinicID
        } else {
            selectedClinicID = filteredClinics.first?.id
        }
        isLoading = false
    }

    func focus(on clinic: VetClinic) {
        selectedClinicID = clinic.id
        cameraPosition = .region(
            MKCoordinateRegion(
                center: clinic.mapCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
            )
        )
    }

    func focusOnUserLocation(_ location: CLLocation?) {
        guard let coordinate = location?.coordinate else { return }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)
            )
        )
    }

    func clearFilters() {
        filter = ClinicSearchFilter()
    }

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0381, longitude: 121.5432),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetClinicRepositoryDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .vetModerationDidChange))
            .sink { [weak self] notification in
                let clinicID = notification.userInfo?[MockClinicRepository.changedClinicIDUserInfoKey] as? String
                Task { @MainActor in
                    await self?.loadClinics(focusingOn: clinicID)
                }
            }
            .store(in: &cancellables)
    }

    private func syncSelectionWithFilteredClinics(shouldFocus: Bool) {
        let visibleClinics = filteredClinics

        guard let firstClinic = visibleClinics.first else {
            selectedClinicID = nil
            return
        }

        if let selectedClinicID, visibleClinics.contains(where: { $0.id == selectedClinicID }) {
            return
        }

        selectedClinicID = firstClinic.id

        if shouldFocus {
            focus(on: firstClinic)
        }
    }
}

extension VetClinic {
    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    func distanceText(from location: CLLocation?) -> String {
        guard let location else { return "距離待定位" }

        let clinicLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let meters = clinicLocation.distance(from: location)

        if meters < 1_000 {
            return "\(Int(meters)) m"
        }

        return String(format: "%.1f km", meters / 1_000)
    }

    var priceLevelText: String {
        String(repeating: "$", count: max(1, min(priceLevel, 3)))
    }
}
