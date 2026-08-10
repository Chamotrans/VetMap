import Foundation

private enum HarnessAction: Equatable {
    case addReview
    case report(String)
    case message(String)
}

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        fatalError("community auth continuation harness failed: \(message)")
    }
}

@main
private struct CommunityAuthContinuationHarness {
    static func main() {
        var restoring = AuthenticatedActionContinuation<HarnessAction>()
        expect(
            restoring.request(.addReview, authentication: .loading)
                == .waitForAuthentication,
            "loading must retain intent without presenting or executing"
        )
        expect(restoring.hasPendingAction, "loading intent was not retained")
        expect(
            restoring.takeIfAuthenticated(.loading) == nil,
            "loading must not consume intent"
        )
        expect(
            restoring.takeIfAuthenticated(.signedIn(userID: "alice")) == .addReview,
            "signed-in restore did not resume the retained action"
        )
        expect(
            restoring.takeIfAuthenticated(.signedIn(userID: "alice")) == nil,
            "repeated auth and onDismiss callbacks replayed a consumed action"
        )

        var cancelled = AuthenticatedActionContinuation<HarnessAction>()
        expect(
            cancelled.request(.report("spam"), authentication: .signedOut)
                == .presentLogin,
            "signed-out request must present LoginView"
        )
        cancelled.cancel()
        expect(
            cancelled.takeIfAuthenticated(.signedIn(userID: "alice")) == nil,
            "cancelled login retained intent"
        )

        var superseded = AuthenticatedActionContinuation<HarnessAction>()
        _ = superseded.request(.addReview, authentication: .loading)
        expect(
            superseded.request(
                .message("bob"),
                authentication: .signedIn(userID: "alice")
            ) == .perform(.message("bob")),
            "authenticated gesture did not run immediately"
        )
        expect(
            !superseded.hasPendingAction,
            "fresh authenticated gesture left stale loading-state intent"
        )

        let draft = QuoteDraft(
            treatmentType: "夜診",
            estimatedCost: Decimal(string: "880.50")!,
            actualCost: Decimal(string: "900.00"),
            currency: "HKD",
            notes: "immutable draft"
        )
        var draftContinuation = AuthenticatedActionContinuation<QuoteDraft>()
        draftContinuation.deferUntilAuthenticated(draft)
        expect(
            draftContinuation.takeIfAuthenticated(.signedIn(userID: "alice")) == draft,
            "draft changed across authentication"
        )
        expect(
            draftContinuation.takeIfAuthenticated(.signedIn(userID: "alice")) == nil,
            "draft submission was not one-shot"
        )

        expect(
            CommunitySubmissionResult.authenticationRequired == .authenticationRequired,
            "typed authentication result is unavailable"
        )
        expect(
            CommunitySubmissionResult.failed(message: "offline")
                != .authenticationRequired,
            "generic backend failure was misclassified as authentication"
        )

        print("community auth continuation harness: PASS")
    }
}
