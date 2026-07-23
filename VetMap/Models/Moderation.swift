import Foundation

// MARK: - Moderation state

enum ModerationStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case rejected

    var label: String {
        switch self {
        case .pending: "待審核"
        case .approved: "已批准"
        case .rejected: "已拒絕"
        }
    }
}

enum SubmissionType: String, Codable, CaseIterable {
    case clinic
    case review
    case quote

    var label: String {
        switch self {
        case .clinic: "診所"
        case .review: "評價"
        case .quote: "報價"
        }
    }

    var publicCollection: String {
        switch self {
        case .clinic: "clinics"
        case .review: "reviews"
        case .quote: "quotes"
        }
    }
}

// A single Firestore `submissions` queue is used for every kind of UGC.
// Optional typed payloads keep the public seed models unchanged and decodable.
struct ModerationSubmission: Identifiable, Codable, Equatable {
    let id: String
    var type: SubmissionType
    var authorId: String
    var authorName: String
    var status: ModerationStatus
    var submittedAt: Date
    var clinicName: String?
    var clinic: VetClinic?
    var review: Review?
    var quote: Quote?
    var reviewedAt: Date?
    var reviewedBy: String?

    var publicDocumentID: String? {
        switch type {
        case .clinic: clinic?.id
        case .review: review?.id
        case .quote: quote?.id
        }
    }
}

// MARK: - Reports

enum ReportTargetType: String, Codable, CaseIterable {
    case clinic
    case review
    case quote

    var label: String {
        switch self {
        case .clinic: "診所"
        case .review: "評價"
        case .quote: "報價"
        }
    }

    var systemImage: String {
        switch self {
        case .clinic: "cross.case.fill"
        case .review: "text.bubble.fill"
        case .quote: "dollarsign.circle.fill"
        }
    }

    var publicCollection: String {
        switch self {
        case .clinic: "clinics"
        case .review: "reviews"
        case .quote: "quotes"
        }
    }
}

struct Report: Identifiable, Codable, Equatable {
    let id: String
    var targetType: ReportTargetType
    var targetId: String
    var targetTitle: String
    var clinicId: String?
    var reason: String
    var reporterId: String
    var createdAt: Date
    var status: ModerationStatus
    var resolvedAt: Date?
    var resolvedBy: String?

    init(
        id: String,
        targetType: ReportTargetType,
        targetId: String,
        targetTitle: String,
        clinicId: String? = nil,
        reason: String,
        reporterId: String,
        createdAt: Date = Date(),
        status: ModerationStatus = .pending,
        resolvedAt: Date? = nil,
        resolvedBy: String? = nil
    ) {
        self.id = id
        self.targetType = targetType
        self.targetId = targetId
        self.targetTitle = targetTitle
        self.clinicId = clinicId
        self.reason = reason
        self.reporterId = reporterId
        self.createdAt = createdAt
        self.status = status
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
    }
}

struct ReportTargetSummary: Equatable {
    let id: String
    let type: ReportTargetType
    let title: String
    let details: String
    let authorId: String?
}

// Public moderation metadata is separate from the seed-compatible content models.
struct ContentModerationState: Identifiable, Codable, Equatable {
    let id: String
    var type: ReportTargetType
    var targetId: String
    var isRemoved: Bool
    var isPinned: Bool
    var updatedAt: Date
    var updatedBy: String
}

// MARK: - Queue presentation helpers

struct PendingClinic: Identifiable, Codable, Equatable {
    var submissionId: String
    var clinic: VetClinic
    var authorId: String
    var authorName: String
    var submittedAt: Date

    var id: String { submissionId }
}

struct PendingReview: Identifiable, Codable, Equatable {
    var submissionId: String
    var review: Review
    var clinicName: String
    var authorId: String
    var submittedAt: Date

    var id: String { submissionId }
}

struct PendingQuote: Identifiable, Codable, Equatable {
    var submissionId: String
    var quote: Quote
    var clinicName: String
    var authorId: String
    var submittedAt: Date

    var id: String { submissionId }
}

// MARK: - On-device preflight

enum ContentSafetyError: LocalizedError {
    case empty
    case tooLong
    case disallowedContent
    case excessiveLinks

    var errorDescription: String? {
        switch self {
        case .empty: "內容不可留空。"
        case .tooLong: "內容過長，請縮短後再提交。"
        case .disallowedContent: "內容可能包含冒犯、仇恨或危險字眼，請修改後再提交。"
        case .excessiveLinks: "內容包含過多連結，請移除廣告或垃圾訊息後再提交。"
        }
    }
}

enum ContentSafety {
    private static let blockedTerms = [
        "去死", "仇恨言論", "殺死", "色情服務", "賣藥", "代購處方"
    ]

    /// This is a fast client-side guard, not an approval decision.
    /// Every accepted item still enters the human moderation queue.
    static func validate(_ values: [String], maximumLength: Int = 4_000) throws {
        let text = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        guard !text.isEmpty else { throw ContentSafetyError.empty }
        guard text.count <= maximumLength else { throw ContentSafetyError.tooLong }

        let normalized = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hant")
        )
        guard !blockedTerms.contains(where: { normalized.localizedCaseInsensitiveContains($0) }) else {
            throw ContentSafetyError.disallowedContent
        }

        let linkCount = normalized.components(separatedBy: "http://").count - 1
            + normalized.components(separatedBy: "https://").count - 1
        guard linkCount <= 2 else { throw ContentSafetyError.excessiveLinks }
    }
}
