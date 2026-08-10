import Foundation

@main
enum ClinicFavoritesHarness {
    static func main() {
        let raw = [
            " clinic-a ",
            "clinic-a",
            "clinic-b",
            "-unsafe",
            "unsafe/id",
            String(repeating: "x", count: 201)
        ]
        let normalized = ClinicFavorites.normalized(raw)
        precondition(
            normalized == ["clinic-a", "clinic-b"],
            "normalization must trim, deduplicate and reject unsafe IDs"
        )
        precondition(
            !ClinicFavorites.isValidClinicID("clinic-a\n"),
            "a partial regex match must not accept a trailing line break"
        )

        let encoded = ClinicFavorites.encode(normalized)
        precondition(
            ClinicFavorites.decode(encoded) == normalized,
            "persisted favourites must round-trip without reordering"
        )
        precondition(
            ClinicFavorites.decode("not-json").isEmpty,
            "corrupt local cache must fail closed to an empty list"
        )

        var current = ClinicFavorites.setting(
            "clinic-c",
            isFavorite: true,
            in: normalized
        )
        precondition(current == ["clinic-a", "clinic-b", "clinic-c"])
        current = ClinicFavorites.setting(
            "clinic-a",
            isFavorite: false,
            in: current
        )
        precondition(current == ["clinic-b", "clinic-c"])

        let full = (0..<ClinicFavorites.maximumCount).map { "clinic-\($0)" }
        precondition(
            ClinicFavorites.setting("clinic-overflow", isFavorite: true, in: full)
                == full,
            "the account favourites list must stop at its documented cap"
        )

        let savedCatalog = SavedCatalogItems.normalized([
            " hk-service-grm-001 ",
            "hk-service-grm-001",
            "insurance-hk-fwd",
            "product-fish-oil",
            "insurance-hk-bad/value"
        ])
        precondition(
            savedCatalog == ["hk-service-grm-001", "insurance-hk-fwd"],
            "saved catalog IDs must be canonical, unique and stably ordered"
        )
        precondition(
            SavedCatalogItems.kind(for: savedCatalog[0]) == .service
                && SavedCatalogItems.kind(for: savedCatalog[1]) == .insurance,
            "service and insurance IDs must remain distinguishable"
        )
        precondition(
            SavedCatalogItems.kind(for: "hk-service-grm-001\n") == nil,
            "catalog validation must reject partial regex matches"
        )
        precondition(
            SavedCatalogItems.kind(for: "hk-service-sup-013") == nil,
            "unpublished catalog gaps must remain unavailable"
        )
        let catalogIDs: (String, [Int]) -> [String] = { prefix, numbers in
            numbers.map { "hk-service-\(prefix)-\(String(format: "%03d", $0))" }
        }
        let expectedCatalogIDs = catalogIDs(
            "sup",
            Array(1...12) + [17] + Array(19...33) + Array(41...62)
        ) + catalogIDs(
            "grm",
            Array(1...28) + Array(35...56)
        ) + catalogIDs(
            "fun",
            Array(1...24)
        ) + [
            "insurance-hk-fwd",
            "insurance-hk-onedegree",
            "insurance-hk-bluecross"
        ]
        precondition(
            SavedCatalogItems.allowedItemIDs == expectedCatalogIDs,
            "Swift and Firestore must share the exact 127-item allowlist"
        )
        var saved = SavedCatalogItems.setting(
            "hk-service-sup-001",
            isSaved: true,
            in: savedCatalog
        )
        saved = SavedCatalogItems.setting(
            "insurance-hk-fwd",
            isSaved: false,
            in: saved
        )
        precondition(
            saved == ["hk-service-grm-001", "hk-service-sup-001"],
            "saved catalog add/remove must be stable and reversible"
        )
        precondition(
            SavedCatalogItems.decode(SavedCatalogItems.encode(saved)) == saved,
            "saved catalog cache must round-trip"
        )
        precondition(
            SavedCatalogItems.setting(
                " legacy-product ",
                isSaved: false,
                in: [" legacy-product ", "hk-service-sup-001"]
            ) == ["hk-service-sup-001"],
            "legacy values must be preserved exactly until arrayRemove"
        )
        precondition(
            SavedCatalogItems.rollingBack(
                " legacy-product ",
                attemptedSave: false,
                previousItemIDs: [" legacy-product ", "hk-service-sup-001"],
                currentItemIDs: ["hk-service-sup-001", "hk-service-grm-001"]
            ) == [" legacy-product ", "hk-service-sup-001", "hk-service-grm-001"],
            "a failed legacy removal must preserve concurrent successful items"
        )
        let concurrentAdds = SavedCatalogItems.setting(
            "hk-service-grm-002",
            isSaved: true,
            in: SavedCatalogItems.setting(
                "hk-service-grm-001",
                isSaved: true,
                in: []
            )
        )
        precondition(
            SavedCatalogItems.setting(
                "hk-service-grm-001",
                isSaved: false,
                in: concurrentAdds
            ) == ["hk-service-grm-002"],
            "one item rollback must preserve a concurrent successful item"
        )
        precondition(
            SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: "alice",
                expectedGeneration: 4,
                currentGeneration: 4
            ),
            "the active account and generation must accept their own snapshot"
        )
        precondition(
            !SavedCatalogItems.isCurrentSession(
                expectedUserID: "alice",
                activeUserID: "bob",
                expectedGeneration: 4,
                currentGeneration: 4
            )
                && !SavedCatalogItems.isCurrentSession(
                    expectedUserID: "alice",
                    activeUserID: "alice",
                    expectedGeneration: 3,
                    currentGeneration: 4
                ),
            "account switches and stale generations must fail closed"
        )

        print(
            "clinicFavorites: true; catalogFavorites: true; "
                + "normalized: 2; maximum: \(ClinicFavorites.maximumCount)"
        )
    }
}
