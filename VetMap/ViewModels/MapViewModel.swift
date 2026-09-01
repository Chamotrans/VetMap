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

/// Urgent care shows only clinics whose current, source-backed schedule confirms
/// they are open now. Missing or expired availability is excluded rather than
/// guessed; the ordinary directory remains available after urgent mode ends.
func urgentClinicOrdering(
    _ clinics: [VetClinic],
    from location: CLLocation?,
    at date: Date
) -> [VetClinic] {
    clinics.filter { $0.isOpen(at: date) }.sorted { lhs, rhs in
        let lhsRank = lhs.availabilitySortRank(at: date)
        let rhsRank = rhs.availabilitySortRank(at: date)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        if let location {
            let lhsDistance = lhs.mapCoordinate.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: location)
            }
            let rhsDistance = rhs.mapCoordinate.map {
                CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                    .distance(from: location)
            }

            switch (lhsDistance, rhsDistance) {
            case let (.some(lhsDistance), .some(rhsDistance)):
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
        }

        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison != .orderedSame {
            return nameComparison == .orderedAscending
        }
        return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
    }
}

@MainActor
@Observable
final class MapViewModel {
    private(set) var clinics: [VetClinic] = []
    var selectedClinicID: String?
    var cameraPosition: MapCameraPosition
    var filter = ClinicSearchFilter() {
        didSet {
            if filter != oldValue {
                isUrgentMode = false
            }
            syncSelectionWithFilteredClinics(shouldFocus: true)
        }
    }
    private(set) var isUrgentMode = false
    private(set) var contextualLocation: CLLocation?
    var isLoading = false
    var networkError: String?
    private(set) var availabilityNow = Date()

    private let firebase: FirebaseService
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var loadRequestGeneration = 0
    @ObservationIgnored private var testingDirectoryClinics: [VetClinic]?

    init(
        repository _: MockClinicRepository = MockClinicRepository(),
        firebase: FirebaseService = .shared
    ) {
        self.firebase = firebase
        self.cameraPosition = .region(Self.defaultRegion)
        observeRepositoryChanges()
        observeAvailabilityClock()
    }

    /// A non-observing seam for deterministic model tests. Production data
    /// still enters exclusively through the normal asynchronous entry point.
    init(testingClinics: [VetClinic], at availabilityNow: Date) {
        self.firebase = .shared
        self.clinics = testingClinics
        self.testingDirectoryClinics = testingClinics
        self.availabilityNow = availabilityNow
        self.cameraPosition = .region(Self.defaultRegion)
    }

    var selectedClinic: VetClinic? {
        guard let selectedClinicID else { return filteredClinics.first }
        return filteredClinics.first { $0.id == selectedClinicID }
    }

    var directoryClinics: [VetClinic] {
        if let testingDirectoryClinics {
            return testingDirectoryClinics
        }
        return clinics.filter {
            !ModerationStore.shared.removedClinicIDs.contains($0.id)
        }
    }

    var filteredClinics: [VetClinic] {
        if isUrgentMode {
            return urgentClinicOrdering(
                directoryClinics,
                from: contextualLocation,
                at: availabilityNow
            )
        }
        return filter.results(from: directoryClinics, at: availabilityNow)
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
        isUrgentMode = false
        filter = ClinicSearchFilter()
    }

    /// Called only from the guardian's explicit urgent-care action. Ordinary
    /// filters are cleared because urgent mode has a distinct, transparent
    /// open-now contract rather than silently combining incompatible filters.
    func activateUrgentMode() {
        filter = ClinicSearchFilter()
        isUrgentMode = true
        // Urgent activation always selects the deterministic first open
        // result. Deactivation intentionally does not clear selection.
        selectedClinicID = nil
        syncSelectionWithFilteredClinics(shouldFocus: true)
    }

    /// Leaves urgent ranking and restores ordinary directory sorting. The
    /// existing selection is retained whenever it remains visible.
    func deactivateUrgentMode() {
        isUrgentMode = false
        syncSelectionWithFilteredClinics(shouldFocus: true)
    }

    func toggleUrgentMode() {
        if isUrgentMode {
            deactivateUrgentMode()
        } else {
            activateUrgentMode()
        }
    }

    func updateContextualLocation(_ location: CLLocation?) {
        contextualLocation = location
        guard isUrgentMode else { return }
        // A fresh location can change the explicit urgent ranking contract.
        selectedClinicID = nil
        syncSelectionWithFilteredClinics(shouldFocus: false)
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
        let reconciledID: String?
        reconciledID = reconciledClinicSelection(
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
