import Foundation

private func require(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ChatDraftRecoveryHarness {
    static func main() {
        let restored = ChatDraftFailureRecovery.recover(
            failedBody: "第一則訊息",
            currentDraft: ""
        )
        require(restored.composerDraft == "第一則訊息", "empty composer should restore failed body")
        require(restored.retryBody == nil, "restored body should not also become a retry")

        let preserved = ChatDraftFailureRecovery.recover(
            failedBody: "第一則訊息",
            currentDraft: "正在輸入第二則訊息"
        )
        require(preserved.composerDraft == "正在輸入第二則訊息", "new draft must never be overwritten")
        require(preserved.retryBody == "第一則訊息", "failed body must remain independently retryable")

        let whitespace = ChatDraftFailureRecovery.recover(
            failedBody: "A",
            currentDraft: " "
        )
        require(whitespace.composerDraft == " ", "even an in-progress whitespace draft must be preserved exactly")
        require(whitespace.retryBody == "A", "failed body should remain retryable when composer contains whitespace")

        print("PASS: chat draft recovery preserves new input and failed-message retry")
    }
}
