import Foundation

/// Local persistence used by previews and legacy on-device drafts.
///
/// App Store release builds intentionally contain no bundled clinic directory.
/// Public clinics come only from the approved Firestore collection. A bundled
/// directory may return after its source and commercial reuse rights have been
/// documented in a release rights packet.
struct MockClinicRepository {
    private let localFileURL: URL
    private let fileManager: FileManager

    init(
        localFileURL: URL = Self.defaultLocalFileURL(),
        fileManager: FileManager = .default
    ) {
        self.localFileURL = localFileURL
        self.fileManager = fileManager
    }

    func fetchClinics() -> [VetClinic] {
        fetchLocalClinics()
    }

    func addClinic(_ clinic: VetClinic) throws {
        var localClinics = fetchLocalClinics()

        if let existingIndex = localClinics.firstIndex(where: { $0.id == clinic.id }) {
            localClinics[existingIndex] = clinic
        } else {
            localClinics.append(clinic)
        }

        try saveLocalClinics(localClinics)
        NotificationCenter.default.post(
            name: .vetClinicRepositoryDidChange,
            object: nil,
            userInfo: [Self.changedClinicIDUserInfoKey: clinic.id]
        )
    }

    func fetchLocalClinics() -> [VetClinic] {
        guard fileManager.fileExists(atPath: localFileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: localFileURL)
            return try Self.decoder.decode([VetClinic].self, from: data)
        } catch {
            return []
        }
    }

    private func saveLocalClinics(_ clinics: [VetClinic]) throws {
        let directory = localFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try Self.encoder.encode(clinics)
        try data.write(to: localFileURL, options: [.atomic])
    }

    private static func defaultLocalFileURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "VetMap", directoryHint: .isDirectory)
            .appending(path: "clinics.json")
    }

    static let changedClinicIDUserInfoKey = "changedClinicID"

    #if DEBUG
    /// Synthetic fixture for unit tests and SwiftUI previews only.
    static let hkClinics: [VetClinic] = [
        VetClinic(
            id: "debug-clinic",
            name: "VetMap 測試診所",
            address: "香港測試地址",
            coordinate: ClinicCoordinate(latitude: 22.3193, longitude: 114.1694),
            phone: "",
            website: nil,
            openingHours: ["今日": "只供測試"],
            services: ["一般診療"],
            avgRating: 0,
            reviewCount: 0,
            priceLevel: 1,
            images: [],
            tags: ["測試資料"],
            createdAt: Date(timeIntervalSince1970: 1_749_200_000),
            updatedAt: Date(timeIntervalSince1970: 1_749_200_000),
            reportedBy: "debug-fixture",
            verified: false
        )
    ]
    #else
    static let hkClinics: [VetClinic] = []
    #endif

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension Notification.Name {
    static let vetClinicRepositoryDidChange = Notification.Name("vetClinicRepositoryDidChange")
}
