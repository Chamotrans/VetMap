import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

func reconciledClinicSelection(currentID: String?, visibleIDs: [String]) -> String? {
    guard let firstVisibleID = visibleIDs.first else { return nil }
    guard let currentID, visibleIDs.contains(currentID) else {
        return firstVisibleID
    }
    return currentID
}

func pendingMapLocationCount(directoryCount: Int, markerCount: Int) -> Int {
    max(directoryCount - markerCount, 0)
}

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
    private(set) var availabilityNow = Date()

    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var loadRequestGeneration = 0

    init(
        repository _: MockClinicRepository = MockClinicRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.firebase = firebase
        self.cameraPosition = .region(Self.defaultRegion)
        observeRepositoryChanges()
        observeAvailabilityClock()
    }

    var selectedClinic: VetClinic? {
        guard let selectedClinicID else { return filteredClinics.first }
        return filteredClinics.first { $0.id == selectedClinicID }
    }

    var directoryClinics: [VetClinic] {
        clinics.filter {
            !ModerationStore.shared.removedClinicIDs.contains($0.id)
        }
    }

    var filteredClinics: [VetClinic] {
        filter.results(from: directoryClinics, at: availabilityNow)
    }

    /// The directory can contain approved clinics whose addresses have not yet
    /// been reliably geocoded. Only this subset is safe to render as map pins.
    var mappableClinics: [VetClinic] {
        filteredClinics.filter { $0.mapCoordinate != nil }
    }

    var pendingLocationCount: Int {
        pendingMapLocationCount(
            directoryCount: filteredClinics.count,
            markerCount: mappableClinics.count
        )
    }

    func loadClinics() {
        let requestGeneration = beginClinicLoad()
        Task {
            await performClinicLoad(
                focusingOn: nil,
                requestGeneration: requestGeneration
            )
        }
    }

    func retryLoad() {
        loadClinics()
    }

    private func reloadClinics(focusingOn clinicID: String?) async {
        let requestGeneration = beginClinicLoad()
        await performClinicLoad(
            focusingOn: clinicID,
            requestGeneration: requestGeneration
        )
    }

    private func beginClinicLoad() -> Int {
        loadRequestGeneration &+= 1
        isLoading = true
        networkError = nil
        return loadRequestGeneration
    }

    private func performClinicLoad(
        focusingOn clinicID: String?,
        requestGeneration: Int
    ) async {
        guard requestGeneration == loadRequestGeneration else { return }
        defer {
            if requestGeneration == loadRequestGeneration {
                isLoading = false
            }
        }

        let previousSelectedClinicID = selectedClinicID
        await ModerationStore.shared.refreshPublicState()
        do {
            let fetchedClinics = try await firebase.fetchClinics()
            guard requestGeneration == loadRequestGeneration else { return }
            clinics = fetchedClinics
        } catch {
            guard requestGeneration == loadRequestGeneration else { return }
            networkError = "雲端診所資料暫時無法載入：\(error.localizedDescription)"
            CrashReporting.recordError(error, domain: "MapViewModel.loadClinics")
        }

        guard requestGeneration == loadRequestGeneration else { return }
        if let clinicID, let clinic = filteredClinics.first(where: { $0.id == clinicID }) {
            focus(on: clinic)
        } else if let previousSelectedClinicID, filteredClinics.contains(where: { $0.id == previousSelectedClinicID }) {
            selectedClinicID = previousSelectedClinicID
        } else {
            selectedClinicID = filteredClinics.first?.id
        }
    }

    func focus(on clinic: VetClinic) {
        selectedClinicID = clinic.id
        guard let coordinate = clinic.mapCoordinate else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
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
        center: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694),
        span: MKCoordinateSpan(latitudeDelta: 0.24, longitudeDelta: 0.24)
    )

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetClinicRepositoryDidChange)
            .merge(with: NotificationCenter.default.publisher(for: .vetModerationDidChange))
            .sink { [weak self] notification in
                let clinicID = notification.userInfo?[MockClinicRepository.changedClinicIDUserInfoKey] as? String
                Task { @MainActor in
                    await self?.reloadClinics(focusingOn: clinicID)
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
                    self?.syncSelectionWithFilteredClinics(shouldFocus: false)
                }
            }
            .store(in: &cancellables)
    }

    private func syncSelectionWithFilteredClinics(shouldFocus: Bool) {
        let visibleClinics = filteredClinics
        let reconciledID = reconciledClinicSelection(
            currentID: selectedClinicID,
            visibleIDs: visibleClinics.map(\.id)
        )
        guard reconciledID != selectedClinicID else {
            return
        }

        selectedClinicID = reconciledID

        if shouldFocus,
            let reconciledID,
            let clinic = visibleClinics.first(where: { $0.id == reconciledID }) {
            focus(on: clinic)
        }
    }
}

extension VetClinic {
    var mapCoordinate: CLLocationCoordinate2D? {
        guard hasReliableHongKongCoordinate, let coordinate else { return nil }
        let mapCoordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        guard CLLocationCoordinate2DIsValid(mapCoordinate) else { return nil }
        return mapCoordinate
    }

    func distanceText(from location: CLLocation?) -> String {
        guard let mapCoordinate else { return "位置待確認" }
        guard let location else { return "距離待定位" }

        let clinicLocation = CLLocation(
            latitude: mapCoordinate.latitude,
            longitude: mapCoordinate.longitude
        )
        let meters = clinicLocation.distance(from: location)

        if meters < 1_000 {
            return "\(Int(meters)) m"
        }

        return String(format: "%.1f km", meters / 1_000)
    }

    var priceLevelText: String {
        guard priceLevel > 0 else { return "" }
        return String(repeating: "$", count: min(priceLevel, 3))
    }
}
