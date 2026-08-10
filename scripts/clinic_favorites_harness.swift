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

        print("clinicFavorites: true; normalized: 2; maximum: \(ClinicFavorites.maximumCount)")
    }
}
