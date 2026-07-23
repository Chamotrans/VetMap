import Combine
import Foundation

/// Firestore-backed moderation state.
///
/// This store deliberately has no local persistence: showing a local success
/// after a failed cloud write would make the queue and admin portal disagree.
@MainActor
final class ModerationStore: ObservableObject {
    static let shared = ModerationStore()

    @Published private(set) var submissions: [ModerationSubmission] = []
    @Published private(set) var reports: [Report] = []
    @Published private(set) var reportTargetsByReportID: [String: ReportTargetSummary] = [:]
    @Published private(set) var pinnedClinicIDs: Set<String> = []
    @Published private(set) var removedClinicIDs: Set<String> = []
    @Published private(set) var removedReviewIDs: Set<String> = []
    @Published private(set) var removedQuoteIDs: Set<String> = []
    @Published private(set) var blockedUserIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let firebase: FirebaseService

    init(firebase: FirebaseService = .shared) {
        self.firebase = firebase
        Task { await refreshPublicState() }
    }

    var pendingClinics: [PendingClinic] {
        submissions.compactMap { submission in
            guard submission.status == .pending, let clinic = submission.clinic else { return nil }
            return PendingClinic(
                submissionId: submission.id,
                clinic: clinic,
                authorId: submission.authorId,
                authorName: submission.authorName,
                submittedAt: submission.submittedAt
            )
        }
    }

    var pendingReviews: [PendingReview] {
        submissions.compactMap { submission in
            guard submission.status == .pending, let review = submission.review else { return nil }
            return PendingReview(
                submissionId: submission.id,
                review: review,
                clinicName: submission.clinicName ?? review.clinicId,
                authorId: submission.authorId,
                submittedAt: submission.submittedAt
            )
        }
    }

    var pendingQuotes: [PendingQuote] {
        submissions.compactMap { submission in
            guard submission.status == .pending, let quote = submission.quote else { return nil }
            return PendingQuote(
                submissionId: submission.id,
                quote: quote,
                clinicName: submission.clinicName ?? quote.clinicId,
                authorId: submission.authorId,
                submittedAt: submission.submittedAt
            )
        }
    }

    var pendingReportsCount: Int {
        reports.filter { $0.status == .pending }.count
    }

    var totalPendingCount: Int {
        pendingClinics.count + pendingReviews.count + pendingQuotes.count + pendingReportsCount
    }

    func isPinned(_ clinicID: String) -> Bool {
        pinnedClinicIDs.contains(clinicID)
    }

    func isRemoved(clinicID: String) -> Bool {
        removedClinicIDs.contains(clinicID)
    }

    func isRemoved(reviewID: String) -> Bool {
        removedReviewIDs.contains(reviewID)
    }

    func isRemoved(quoteID: String) -> Bool {
        removedQuoteIDs.contains(quoteID)
    }

    func isBlocked(userID: String) -> Bool {
        blockedUserIDs.contains(userID)
    }

    func canonicalTarget(for report: Report) -> ReportTargetSummary? {
        reportTargetsByReportID[report.id]
    }

    // MARK: - Refresh

    func refreshPublicState() async {
        do {
            let oldPinned = pinnedClinicIDs
            let oldRemovedClinics = removedClinicIDs
            let oldRemovedReviews = removedReviewIDs
            let oldRemovedQuotes = removedQuoteIDs
            let oldBlocked = blockedUserIDs
            let states = try await firebase.fetchContentStates()
            apply(states: states)
            do {
                blockedUserIDs = try await firebase.fetchBlockedUserIDs()
            } catch FirebaseError.authenticationRequired {
                blockedUserIDs = []
            }
            errorMessage = nil
            if oldPinned != pinnedClinicIDs
                || oldRemovedClinics != removedClinicIDs
                || oldRemovedReviews != removedReviewIDs
                || oldRemovedQuotes != removedQuoteIDs
                || oldBlocked != blockedUserIDs {
                notifyChange()
            }
        } catch {
            record(error, domain: "ModerationStore.refreshPublicState")
        }
    }

    func refreshAdminQueue() async {
        isLoading = true
        defer { isLoading = false }

        do {
            submissions = try await firebase.fetchPendingSubmissions()
            let fetchedReports = try await firebase.fetchReports()
            var canonicalTargets: [String: ReportTargetSummary] = [:]
            for report in fetchedReports {
                do {
                    canonicalTargets[report.id] = try await firebase
                        .fetchCanonicalReportTarget(report)
                } catch {
                    CrashReporting.recordError(
                        error,
                        domain: "ModerationStore.fetchCanonicalReportTarget"
                    )
                }
            }
            reports = fetchedReports
            reportTargetsByReportID = canonicalTargets
            apply(states: try await firebase.fetchContentStates())
            errorMessage = nil
            notifyChange()
        } catch {
            record(error, domain: "ModerationStore.refreshAdminQueue")
        }
    }

    // MARK: - User submissions

    func submitClinic(_ clinic: VetClinic) async throws {
        do {
            try await firebase.submitClinic(clinic)
            errorMessage = nil
        } catch {
            record(error, domain: "ModerationStore.submitClinic")
            throw error
        }
    }

    func submitReview(_ review: Review, clinicName: String) async throws {
        do {
            try await firebase.submitReview(review, clinicName: clinicName)
            errorMessage = nil
        } catch {
            record(error, domain: "ModerationStore.submitReview")
            throw error
        }
    }

    func submitQuote(_ quote: Quote, clinicName: String) async throws {
        do {
            try await firebase.submitQuote(quote, clinicName: clinicName)
            errorMessage = nil
        } catch {
            record(error, domain: "ModerationStore.submitQuote")
            throw error
        }
    }

    func submitReport(
        targetType: ReportTargetType,
        targetId: String,
        targetTitle: String,
        clinicId: String?,
        reason: String
    ) async throws {
        do {
            try await firebase.submitReport(
                targetType: targetType,
                targetId: targetId,
                targetTitle: targetTitle,
                clinicId: clinicId,
                reason: reason
            )
            errorMessage = nil
        } catch {
            record(error, domain: "ModerationStore.submitReport")
            throw error
        }
    }

    func blockUser(_ userID: String) async throws {
        do {
            try await firebase.blockUser(userID)
            blockedUserIDs.insert(userID)
            errorMessage = nil
            notifyChange()
        } catch {
            record(error, domain: "ModerationStore.blockUser")
            throw error
        }
    }

    func unblockUser(_ userID: String) async throws {
        do {
            try await firebase.unblockUser(userID)
            blockedUserIDs.remove(userID)
            errorMessage = nil
            notifyChange()
        } catch {
            record(error, domain: "ModerationStore.unblockUser")
            throw error
        }
    }

    // MARK: - Admin moderation

    func approveSubmission(id: String) async {
        await performAdminAction(domain: "ModerationStore.approveSubmission") {
            try await firebase.approveSubmission(id: id)
        }
    }

    func rejectSubmission(id: String) async {
        await performAdminAction(domain: "ModerationStore.rejectSubmission") {
            try await firebase.rejectSubmission(id: id)
        }
    }

    func resolveReport(id: String, takeDown: Bool) async {
        await performAdminAction(domain: "ModerationStore.resolveReport") {
            try await firebase.resolveReport(id: id, takeDown: takeDown)
        }
    }

    func togglePin(_ clinicID: String) async {
        let newValue = !pinnedClinicIDs.contains(clinicID)
        await performAdminAction(domain: "ModerationStore.togglePin") {
            try await firebase.setClinicPinned(clinicId: clinicID, pinned: newValue)
        }
    }

    func setClinicRemoved(_ clinicID: String, _ removed: Bool) async {
        await performAdminAction(domain: "ModerationStore.setClinicRemoved") {
            try await firebase.setContentRemoved(type: .clinic, targetId: clinicID, removed: removed)
        }
    }

    func setReviewRemoved(_ reviewID: String, _ removed: Bool) async {
        await performAdminAction(domain: "ModerationStore.setReviewRemoved") {
            try await firebase.setContentRemoved(type: .review, targetId: reviewID, removed: removed)
        }
    }

    func setQuoteRemoved(_ quoteID: String, _ removed: Bool) async {
        await performAdminAction(domain: "ModerationStore.setQuoteRemoved") {
            try await firebase.setContentRemoved(type: .quote, targetId: quoteID, removed: removed)
        }
    }

    // MARK: - Helpers

    private func performAdminAction(
        domain: String,
        action: () async throws -> Void
    ) async {
        do {
            try await action()
            errorMessage = nil
            await refreshAdminQueue()
        } catch {
            record(error, domain: domain)
        }
    }

    private func apply(states: [ContentModerationState]) {
        pinnedClinicIDs = Set(
            states.filter { $0.type == .clinic && $0.isPinned && !$0.isRemoved }.map(\.targetId)
        )
        removedClinicIDs = Set(
            states.filter { $0.type == .clinic && $0.isRemoved }.map(\.targetId)
        )
        removedReviewIDs = Set(
            states.filter { $0.type == .review && $0.isRemoved }.map(\.targetId)
        )
        removedQuoteIDs = Set(
            states.filter { $0.type == .quote && $0.isRemoved }.map(\.targetId)
        )
    }

    private func record(_ error: Error, domain: String) {
        errorMessage = error.localizedDescription
        CrashReporting.recordError(error, domain: domain)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .vetModerationDidChange, object: nil)
    }
}

extension Notification.Name {
    static let vetModerationDidChange = Notification.Name("vetModerationDidChange")
}
