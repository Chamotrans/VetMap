import Foundation

@main
enum LocationPermissionPolicyHarness {
    static func main() {
        precondition(
            LocationButtonPolicy.outcome(for: .notDetermined) == .requestedPermission,
            "only an explicit location-button tap may start the permission prompt"
        )
        precondition(
            LocationButtonPolicy.outcome(for: .authorized) == .requestedLocation,
            "an authorised button tap must request a fresh one-shot location"
        )
        precondition(
            LocationButtonPolicy.outcome(for: .denied) == .requiresSettings,
            "a denied permission must recover through Settings without prompt loops"
        )
        precondition(
            LocationButtonPolicy.outcome(for: .restricted) == .requiresSettings,
            "a restricted permission must fail closed with a recovery explanation"
        )

        print("locationPermission: contextual; launchPrompt: false; settingsRecovery: true")
    }
}
