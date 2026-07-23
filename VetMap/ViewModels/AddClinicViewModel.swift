import Foundation

@MainActor
@Observable
final class AddClinicViewModel {
    enum LocationLookupState: Equatable {
        case idle
        case resolving
        case resolved(String)
        case failed(String)
    }

    enum RegionPreset: String, CaseIterable, Identifiable {
        case hongKong = "香港"
        case custom = "手動"

        var id: String { rawValue }
    }

    var name = ""
    var address = "" {
        didSet {
            if oldValue != address {
                locationLookupState = .idle
            }
        }
    }
    var phone = ""
    var website = ""
    var selectedRegion: RegionPreset = .hongKong {
        didSet {
            if selectedRegion != .custom {
                locationLookupState = .idle
            }
        }
    }
    var latitude = ""
    var longitude = ""
    var services = "一般診療, 疫苗"
    var tags = "社群回報"
    var openingHours = "09:00-18:00"
    var priceLevel = 2
    var validationMessage: String?
    private(set) var locationLookupState: LocationLookupState = .idle

    private let geocodingService: GeocodingServicing

    init(geocodingService: GeocodingServicing = GeocodingService()) {
        self.geocodingService = geocodingService
    }

    var canSubmit: Bool {
        !trimmed(name).isEmpty
            && !trimmed(address).isEmpty
            && !trimmed(phone).isEmpty
            && resolvedCoordinate != nil
    }

    var canLookupAddress: Bool {
        !trimmed(address).isEmpty && locationLookupState != .resolving
    }

    var isResolvingLocation: Bool {
        locationLookupState == .resolving
    }

    func lookupAddressLocation() async {
        let query = trimmed(address)
        guard !query.isEmpty else {
            locationLookupState = .failed("請先填寫地址。")
            return
        }

        locationLookupState = .resolving

        do {
            let result = try await geocodingService.resolve(address: query)
            guard query == trimmed(address) else { return }
            guard Self.isHongKongCoordinate(result.coordinate) else {
                locationLookupState = .failed("只接受香港境內的診所位置。")
                return
            }

            selectedRegion = .custom
            latitude = Self.formatCoordinate(result.coordinate.latitude)
            longitude = Self.formatCoordinate(result.coordinate.longitude)
            locationLookupState = .resolved("已找到：\(result.displayName)")
            validationMessage = nil
        } catch {
            guard query == trimmed(address) else { return }

            locationLookupState = .failed("找不到位置，請手動輸入經緯度。")
        }
    }

    func makeClinic() -> VetClinic? {
        guard canSubmit else {
            validationMessage = "請填寫診所名稱、地址、電話和有效位置。"
            return nil
        }

        guard let coordinate = resolvedCoordinate else {
            validationMessage = "請查找地址或輸入有效的香港經緯度。"
            return nil
        }

        guard let uid = AuthViewModel.shared.user?.uid, !uid.isEmpty else {
            validationMessage = "請先登入後再提交診所資料。"
            return nil
        }

        do {
            try ContentSafety.validate([
                name,
                address,
                phone,
                services,
                tags,
                openingHours
            ])
        } catch {
            validationMessage = error.localizedDescription
            return nil
        }

        validationMessage = nil
        let now = Date()
        let normalizedOpeningHours = trimmed(openingHours)

        return VetClinic(
            id: "clinic-\(UUID().uuidString)",
            name: trimmed(name),
            address: trimmed(address),
            coordinate: coordinate,
            phone: trimmed(phone),
            website: websiteURL,
            openingHours: normalizedOpeningHours.isEmpty
                ? [:]
                : ["今日": normalizedOpeningHours],
            services: splitList(services),
            avgRating: 0,
            reviewCount: 0,
            priceLevel: priceLevel,
            images: [],
            tags: splitList(tags),
            createdAt: now,
            updatedAt: now,
            reportedBy: uid,
            verified: false
        )
    }

    private func splitList(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { trimmed(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var websiteURL: URL? {
        let value = trimmed(website)
        guard !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private var resolvedCoordinate: ClinicCoordinate? {
        guard selectedRegion == .custom else { return nil }
        guard
            let latitude = Double(trimmed(latitude)),
            let longitude = Double(trimmed(longitude)),
            Self.isHongKongCoordinate(
                ClinicCoordinate(latitude: latitude, longitude: longitude)
            )
        else {
            return nil
        }

        return ClinicCoordinate(latitude: latitude, longitude: longitude)
    }

    private static func isHongKongCoordinate(_ coordinate: ClinicCoordinate) -> Bool {
        (22.1...22.6).contains(coordinate.latitude)
            && (113.8...114.5).contains(coordinate.longitude)
    }

    private static func formatCoordinate(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
