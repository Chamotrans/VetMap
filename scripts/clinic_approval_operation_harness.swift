import Foundation

@main
struct ClinicApprovalOperationHarness {
    static func main() {
        var passed = 0

        func check(
            _ outcome: ClinicApprovalOperationOutcome,
            resolvesTo expected: ClinicApprovalOperationResolution
        ) {
            precondition(
                ClinicApprovalOperationPolicy.resolution(for: outcome) == expected
            )
            passed += 1
        }

        check(.preflightFailed, resolvesTo: .preflightFailedNoWrite)
        check(.writeFailed, resolvesTo: .writeFailedNoWrite)
        check(.writeSucceededRefreshSucceeded, resolvesTo: .approved)
        check(.writeSucceededRefreshFailed, resolvesTo: .approvedRefreshFailed)

        print("{\"clinicApprovalOperation\":true,\"passed\":\(passed)}")
    }
}
