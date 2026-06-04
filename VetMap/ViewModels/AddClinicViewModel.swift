import Foundation

@MainActor
final class AddClinicViewModel: ObservableObject {
    enum RegionPreset: String, CaseIterable, Identifiable {
        case taipei = "台北"
        case hongKong = "香港"
        case custom = "手動"

        var id: String { rawValue }

        var coordinate: ClinicCoordinate? {
            switch self {
            case .taipei:
                return ClinicCoordinate(latitude: 25.0381, longitude: 121.5432)
            case .hongKong:
                return ClinicCoordinate(latitude: 22.3186, longitude: 114.1693)
            case .custom:
                return nil
            }
        }
    }

    @Published var name = ""
    @Published var address = ""
    @Published var phone = ""
    @Published var website = ""
    @Published var selectedRegion: RegionPreset = .taipei
    @Published var latitude = ""
    @Published var longitude = ""
    @Published var services = "一般診療, 疫苗"
    @Published var tags = "社群回報"
    @Published var openingHours = "09:00-18:00"
    @Published var priceLevel = 2
    @Published var verified = false
    @Published var validationMessage: String?

    var canSubmit: Bool {
        !trimmed(name).isEmpty
            && !trimmed(address).isEmpty
            && !trimmed(phone).isEmpty
            && resolvedCoordinate != nil
    }

    func makeClinic() -> VetClinic? {
        guard canSubmit else {
            validationMessage = "請填寫診所名稱、地址、電話和有效位置。"
            return nil
        }

        guard let coordinate = resolvedCoordinate else {
            validationMessage = "請輸入有效的經緯度。"
            return nil
        }

        validationMessage = nil
        let now = Date()

        return VetClinic(
            id: "clinic-\(UUID().uuidString)",
            name: trimmed(name),
            address: trimmed(address),
            coordinate: coordinate,
            phone: trimmed(phone),
            website: websiteURL,
            openingHours: ["今日": trimmed(openingHours)],
            services: splitList(services),
            avgRating: 0,
            reviewCount: 0,
            priceLevel: priceLevel,
            images: [],
            tags: splitList(tags),
            createdAt: now,
            updatedAt: now,
            reportedBy: "local-user",
            verified: verified
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
        if let presetCoordinate = selectedRegion.coordinate {
            return presetCoordinate
        }

        guard
            let latitude = Double(trimmed(latitude)),
            let longitude = Double(trimmed(longitude)),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else {
            return nil
        }

        return ClinicCoordinate(latitude: latitude, longitude: longitude)
    }
}
