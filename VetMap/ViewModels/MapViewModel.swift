import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
final class MapViewModel: ObservableObject {
    @Published private(set) var clinics: [VetClinic] = []
    @Published var selectedClinicID: String?
    @Published var cameraPosition: MapCameraPosition

    private let repository: MockClinicRepository
    private var cancellables: Set<AnyCancellable> = []

    init(repository: MockClinicRepository = MockClinicRepository()) {
        self.repository = repository
        self.cameraPosition = .region(Self.defaultRegion)
        observeRepositoryChanges()
        loadClinics()
    }

    var selectedClinic: VetClinic? {
        guard let selectedClinicID else { return clinics.first }
        return clinics.first { $0.id == selectedClinicID }
    }

    func loadClinics() {
        loadClinics(focusingOn: nil)
    }

    private func loadClinics(focusingOn clinicID: String?) {
        let previousSelectedClinicID = selectedClinicID
        clinics = repository.fetchClinics()

        if let clinicID, let clinic = clinics.first(where: { $0.id == clinicID }) {
            focus(on: clinic)
        } else if let previousSelectedClinicID, clinics.contains(where: { $0.id == previousSelectedClinicID }) {
            selectedClinicID = previousSelectedClinicID
        } else {
            selectedClinicID = clinics.first?.id
        }
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

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0381, longitude: 121.5432),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    private func observeRepositoryChanges() {
        NotificationCenter.default.publisher(for: .vetClinicRepositoryDidChange)
            .sink { [weak self] notification in
                let clinicID = notification.userInfo?[MockClinicRepository.changedClinicIDUserInfoKey] as? String
                Task { @MainActor in
                    self?.loadClinics(focusingOn: clinicID)
                }
            }
            .store(in: &cancellables)
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
