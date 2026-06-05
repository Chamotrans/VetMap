import CoreLocation
import Foundation

struct GeocodingResult: Equatable {
    let coordinate: ClinicCoordinate
    let displayName: String
}

enum GeocodingServiceError: Error, LocalizedError {
    case emptyAddress
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyAddress:
            return "請先填寫地址。"
        case .notFound:
            return "找不到這個地址的位置。"
        }
    }
}

protocol GeocodingServicing {
    func resolve(address: String) async throws -> GeocodingResult
}

struct GeocodingService: GeocodingServicing {
    func resolve(address: String) async throws -> GeocodingResult {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw GeocodingServiceError.emptyAddress }

        let placemarks = try await CLGeocoder().geocodeAddressString(query)
        guard let placemark = placemarks.first, let location = placemark.location else {
            throw GeocodingServiceError.notFound
        }

        return GeocodingResult(
            coordinate: ClinicCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            displayName: Self.displayName(for: placemark, fallback: query)
        )
    }

    private static func displayName(for placemark: CLPlacemark, fallback: String) -> String {
        let parts = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return fallback }

        var seenParts = Set<String>()
        let uniqueParts = parts.filter { seenParts.insert($0).inserted }
        return uniqueParts.joined(separator: "，")
    }
}
