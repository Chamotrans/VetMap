// Firestore is the authoritative store for public content and moderation.
// Bundled JSON remains a read-only seed/fallback used by the presentation layer.
import Foundation

func decodeFirestoreDocuments<Input, Output>(
    _ documents: [Input],
    documentID: (Input) -> String,
    decode: (Input) throws -> Output,
    onFailure: (String, Error) -> Void
) throws -> [Output] {
    guard !documents.isEmpty else { return [] }

    var decoded: [Output] = []
    var firstError: Error?

    for document in documents {
        do {
            decoded.append(try decode(document))
        } catch {
            if firstError == nil {
                firstError = error
            }
            onFailure(documentID(document), error)
        }
    }

    if decoded.isEmpty, let firstError {
        throw firstError
    }

    return decoded
}

#if canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseCore
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class FirebaseService {
    static let shared = FirebaseService()

    private var firestore: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    private let encoder: Firestore.Encoder = {
        let encoder = Firestore.Encoder()
        encoder.dateEncodingStrategy = .timestamp
        return encoder
    }()

    // MARK: - Public content

    func fetchClinics() async throws -> [VetClinic] {
        let snapshot = try await resolveFirestore()
            .collection("clinics")
            .whereField("status", isEqualTo: ModerationStatus.approved.rawValue)
            .getDocuments()
        return try decodeFirestoreDocuments(
            snapshot.documents,
            documentID: \.documentID,
            decode: { try self.decodeDocument($0, as: VetClinic.self) },
            onFailure: { documentID, error in
                CrashReporting.log("FirebaseService.fetchClinics.decodeFailed documentID=\(documentID)")
                CrashReporting.recordError(
                    error,
                    domain: "FirebaseService.fetchClinics.\(documentID)"
                )
            }
        )
    }

    func searchClinics(query: String) async throws -> [VetClinic] {
        let clinics = try await fetchClinics()
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return clinics }

        return clinics.filter {
            $0.name.localizedCaseInsensitiveContains(term)
                || $0.address.localizedCaseInsensitiveContains(term)
                || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(term) })
                || $0.services.contains(where: { $0.localizedCaseInsensitiveContains(term) })
        }
    }

    // MARK: - Account favourites

    func fetchFavoriteClinicIDs(expectedUserID: String) async throws -> [String] {
        let identity = try authenticatedIdentity()
        guard identity.uid == expectedUserID else {
            throw FirebaseError.authenticationStateChanged
        }
        let snapshot = try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .getDocument()
        guard snapshot.exists else {
            throw FirebaseError.documentNotFound(identity.uid)
        }
        return ClinicFavorites.normalized(
            snapshot.data()?["favoriteClinics"] as? [String] ?? []
        )
    }

    func setClinicFavorite(
        _ clinicID: String,
        isFavorite: Bool,
        expectedUserID: String
    ) async throws {
        let normalizedID = clinicID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ClinicFavorites.isValidClinicID(normalizedID) else {
            throw FirebaseError.invalidFavoriteClinicID
        }
        let identity = try authenticatedIdentity()
        guard identity.uid == expectedUserID else {
            throw FirebaseError.authenticationStateChanged
        }
        try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .updateData([
                "favoriteClinics": isFavorite
                    ? FieldValue.arrayUnion([normalizedID])
                    : FieldValue.arrayRemove([normalizedID]),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func fetchSavedCatalogItemIDs(expectedUserID: String) async throws -> [String] {
        let identity = try authenticatedIdentity()
        guard identity.uid == expectedUserID else {
            throw FirebaseError.authenticationStateChanged
        }
        let snapshot = try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .getDocument()
        guard snapshot.exists else {
            throw FirebaseError.documentNotFound(identity.uid)
        }
        let rawValues = snapshot.data()?["savedProducts"] as? [Any] ?? []
        return SavedCatalogItems.normalizedStored(rawValues.compactMap { $0 as? String })
    }

    func setCatalogItemSaved(
        _ itemID: String,
        isSaved: Bool,
        expectedUserID: String
    ) async throws {
        let normalizedID = isSaved
            ? itemID.trimmingCharacters(in: .whitespacesAndNewlines)
            : itemID
        let validOperation = isSaved
            ? SavedCatalogItems.isValidItemID(normalizedID)
            : SavedCatalogItems.isSafeStoredItemID(normalizedID)
        guard validOperation else {
            throw FirebaseError.invalidSavedCatalogItemID
        }
        let identity = try authenticatedIdentity()
        guard identity.uid == expectedUserID else {
            throw FirebaseError.authenticationStateChanged
        }
        try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .updateData([
                "savedProducts": isSaved
                    ? FieldValue.arrayUnion([normalizedID])
                    : FieldValue.arrayRemove([normalizedID]),
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    func fetchReviews(for clinicId: String) async throws -> [Review] {
        let snapshot = try await resolveFirestore()
            .collection("reviews")
            .whereField("clinicId", isEqualTo: clinicId)
            .whereField("status", isEqualTo: ModerationStatus.approved.rawValue)
            .getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: Review.self) }
    }

    func fetchQuotes(for clinicId: String) async throws -> [Quote] {
        let snapshot = try await resolveFirestore()
            .collection("quotes")
            .whereField("clinicId", isEqualTo: clinicId)
            .whereField("status", isEqualTo: ModerationStatus.approved.rawValue)
            .getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: Quote.self) }
    }

    /// Legacy repository entry points. Firestore rules only allow an admin to
    /// publish directly; user-facing flows must use `submit*` below.
    func addClinic(_ clinic: VetClinic) async throws {
        let (uid, _) = try authenticatedIdentity()
        guard try await isAdmin(uid: uid) else { throw FirebaseError.requiresModeration }
        try await publish(clinic, authorId: clinic.reportedBy)
    }

    func addReview(_ review: Review) async throws {
        let (uid, _) = try authenticatedIdentity()
        guard try await isAdmin(uid: uid) else { throw FirebaseError.requiresModeration }
        try await publish(review, authorId: review.userId)
    }

    func addQuote(_ quote: Quote) async throws {
        let (uid, _) = try authenticatedIdentity()
        guard try await isAdmin(uid: uid) else { throw FirebaseError.requiresModeration }
        try await publish(quote, authorId: quote.userId)
    }

    func markReviewHelpful(reviewId: String) async throws {
        let identity = try authenticatedIdentity()
        guard isSafeDocumentID(reviewId) else { throw FirebaseError.invalidReviewID }
        let db = try resolveFirestore()
        let engagementReference = db.collection("reviewEngagement").document(reviewId)
        let voteReference = engagementReference.collection("voters").document(identity.uid)

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let existingVote = try transaction.getDocument(voteReference)
                guard !existingVote.exists else {
                    throw NSError(
                        domain: "VetMap.FirebaseService",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "你已標記過這則評價。"]
                    )
                }

                let engagement = try transaction.getDocument(engagementReference)
                let existingCount =
                    (engagement.data()?["helpfulCount"] as? NSNumber)?.intValue ?? 0

                transaction.setData(
                    [
                        "reviewId": reviewId,
                        "helpfulCount": existingCount + 1,
                        "updatedAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: engagementReference
                )
                transaction.setData(
                    [
                        "userId": identity.uid,
                        "createdAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: voteReference
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    func fetchReviewHelpfulCounts() async throws -> [String: Int] {
        let snapshot = try await resolveFirestore()
            .collection("reviewEngagement")
            .getDocuments()
        return snapshot.documents.reduce(into: [:]) { result, document in
            if let count = (document.data()["helpfulCount"] as? NSNumber)?.intValue {
                result[document.documentID] = count
            }
        }
    }

    // MARK: - Unified submissions queue

    func submitClinic(_ original: VetClinic) async throws {
        let identity = try authenticatedIdentity()
        var clinic = original
        clinic.reportedBy = identity.uid
        clinic.verified = false
        clinic.updatedAt = Date()

        let submission = ModerationSubmission(
            id: "submission-\(UUID().uuidString)",
            type: .clinic,
            authorId: identity.uid,
            authorName: identity.name,
            status: .pending,
            submittedAt: Date(),
            clinicName: clinic.name,
            clinic: clinic
        )
        try ContentSafety.validate([
            clinic.name,
            clinic.address,
            clinic.phone,
            clinic.services.joined(separator: " "),
            clinic.tags.joined(separator: " ")
        ])
        try await saveSubmission(submission)
    }

    func submitReview(_ original: Review, clinicName: String) async throws {
        let identity = try authenticatedIdentity()
        var review = original
        review.userId = identity.uid
        review.userName = identity.name
        review.updatedAt = Date()

        let submission = ModerationSubmission(
            id: "submission-\(UUID().uuidString)",
            type: .review,
            authorId: identity.uid,
            authorName: identity.name,
            status: .pending,
            submittedAt: Date(),
            clinicName: clinicName,
            review: review
        )
        try ContentSafety.validate([
            review.title,
            review.content,
            review.treatmentType ?? ""
        ])
        try await saveSubmission(submission)
    }

    func submitQuote(_ original: Quote, clinicName: String) async throws {
        let identity = try authenticatedIdentity()
        var quote = original
        quote.userId = identity.uid

        let submission = ModerationSubmission(
            id: "submission-\(UUID().uuidString)",
            type: .quote,
            authorId: identity.uid,
            authorName: identity.name,
            status: .pending,
            submittedAt: Date(),
            clinicName: clinicName,
            quote: quote
        )
        try ContentSafety.validate([quote.treatmentType, quote.notes])
        try await saveSubmission(submission)
    }

    func fetchPendingSubmissions() async throws -> [ModerationSubmission] {
        let snapshot = try await resolveFirestore()
            .collection("submissions")
            .whereField("status", isEqualTo: ModerationStatus.pending.rawValue)
            .getDocuments()
        var decoded: [ModerationSubmission] = []
        for document in snapshot.documents {
            do {
                decoded.append(try decodeDocument(document, as: ModerationSubmission.self))
            } catch {
                // One hostile or legacy document must never make the entire
                // moderation queue unavailable.
                CrashReporting.recordError(
                    error,
                    domain: "FirebaseService.fetchPendingSubmissions.\(document.documentID)"
                )
            }
        }
        return decoded.sorted { $0.submittedAt > $1.submittedAt }
    }

    func approveSubmission(id: String) async throws {
        let db = try resolveFirestore()
        let identity = try authenticatedIdentity()
        guard try await isAdmin(uid: identity.uid) else { throw FirebaseError.adminRequired }

        let reference = db.collection("submissions").document(id)
        let snapshot = try await reference.getDocument()
        guard snapshot.exists else { throw FirebaseError.documentNotFound(id) }
        let submission = try decodeDocument(snapshot, as: ModerationSubmission.self)
        guard submission.status == .pending else { throw FirebaseError.alreadyModerated }
        guard submission.publicDocumentID != nil else { throw FirebaseError.invalidSubmission }
        // The public ID is owned by the approval pipeline, not by the submitted
        // payload. This prevents collisions with bundled or existing content.
        let publicID = "ugc-\(submission.id)"
        let publicReference = db.collection(submission.type.publicCollection).document(publicID)
        let publicSnapshot = try await publicReference.getDocument()
        guard !publicSnapshot.exists else {
            throw FirebaseError.publicDocumentConflict
        }

        var payload: [String: Any]
        switch submission.type {
        case .clinic:
            guard
                let clinic = submission.clinic,
                let publicClinic = ClinicPublicationPolicy.safeProjection(
                    of: clinic,
                    submitterID: submission.authorId
                )
            else {
                // Reject malformed or non-Hong-Kong legacy queue entries before
                // a Firestore batch is constructed.
                throw FirebaseError.invalidSubmission
            }
            payload = try publishedData(
                publicClinic,
                authorId: submission.authorId,
                approvedAt: Date()
            )
        case .review:
            guard let review = submission.review else { throw FirebaseError.invalidSubmission }
            payload = try publishedData(review, authorId: submission.authorId, approvedAt: Date())
        case .quote:
            guard let quote = submission.quote else { throw FirebaseError.invalidSubmission }
            payload = try publishedData(quote, authorId: submission.authorId, approvedAt: Date())
        }
        let canonicalCreatedAt = Timestamp(date: submission.submittedAt)
        payload["id"] = publicID
        payload["createdAt"] = canonicalCreatedAt
        if submission.type != .quote {
            payload["updatedAt"] = canonicalCreatedAt
        }

        let batch = db.batch()
        batch.setData(
            payload,
            forDocument: publicReference
        )
        batch.updateData(
            [
                "status": ModerationStatus.approved.rawValue,
                "reviewedAt": FieldValue.serverTimestamp(),
                "reviewedBy": identity.uid
            ],
            forDocument: reference
        )
        try await batch.commit()
    }

    func rejectSubmission(id: String) async throws {
        let db = try resolveFirestore()
        let identity = try authenticatedIdentity()
        guard try await isAdmin(uid: identity.uid) else { throw FirebaseError.adminRequired }

        try await db.collection("submissions").document(id).updateData([
            "status": ModerationStatus.rejected.rawValue,
            "reviewedAt": FieldValue.serverTimestamp(),
            "reviewedBy": identity.uid
        ])
    }

    // MARK: - Reports

    func submitReport(
        targetType: ReportTargetType,
        targetId: String,
        targetTitle: String,
        clinicId: String?,
        conversationId: String? = nil,
        reason: String
    ) async throws {
        let identity = try authenticatedIdentity()
        try ContentSafety.validate([reason], maximumLength: 500)

        let report = Report(
            id: "\(targetType.rawValue)-\(targetId)-\(identity.uid)",
            targetType: targetType,
            targetId: targetId,
            targetTitle: targetTitle,
            clinicId: clinicId,
            conversationId: conversationId,
            reason: reason,
            reporterId: identity.uid
        )
        let data = try encoder.encode(report)
        let db = try resolveFirestore()
        let batch = db.batch()
        batch.setData(data, forDocument: db.collection("reports").document(report.id))

        if targetType == .message {
            guard let conversationId,
                  isSafeDocumentID(conversationId),
                  isSafeDocumentID(targetId) else {
                throw FirebaseError.invalidReportTarget
            }
            let moderationReference = db.collection("chatModeration")
                .document(conversationId)
            batch.setData(
                [
                    "conversationId": conversationId,
                    "lastReportedMessageId": targetId,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: moderationReference,
                merge: true
            )
            batch.setData(
                [
                    "conversationId": conversationId,
                    "messageId": targetId,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: moderationReference.collection("reportedMessages")
                    .document(targetId),
                merge: true
            )
        }
        try await batch.commit()
    }

    func fetchReports() async throws -> [Report] {
        let snapshot = try await resolveFirestore()
            .collection("reports")
            .whereField("status", isEqualTo: ModerationStatus.pending.rawValue)
            .limit(to: 200)
            .getDocuments()
        return try snapshot.documents
            .map { try decodeDocument($0, as: Report.self) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Resolves the report against authoritative public content or the bundled
    /// seed catalog. The moderation UI must show this value instead of trusting
    /// reporter-supplied titles.
    func fetchCanonicalReportTarget(_ report: Report) async throws -> ReportTargetSummary? {
        guard isSafeDocumentID(report.targetId) else {
            throw FirebaseError.invalidReportTarget
        }
        if report.targetType == .message {
            guard let conversationId = report.conversationId,
                  isSafeDocumentID(conversationId) else {
                throw FirebaseError.invalidReportTarget
            }
            let snapshot = try await resolveFirestore()
                .collection("conversations")
                .document(conversationId)
                .collection("messages")
                .document(report.targetId)
                .getDocument()
            guard snapshot.exists else { return nil }
            let message = try decodeDocument(snapshot, as: ChatMessage.self)
            return ReportTargetSummary(
                id: message.id,
                type: .message,
                title: "聊天室訊息",
                details: message.isDeleted ? "訊息已刪除" : message.body,
                authorId: message.senderId
            )
        }
        let snapshot = try await resolveFirestore()
            .collection(report.targetType.publicCollection)
            .document(report.targetId)
            .getDocument()

        if snapshot.exists {
            switch report.targetType {
            case .clinic:
                let clinic = try decodeDocument(snapshot, as: VetClinic.self)
                return ReportTargetSummary(
                    id: clinic.id,
                    type: .clinic,
                    title: clinic.name,
                    details: [
                        clinic.address,
                        "電話：\(clinic.phone)",
                        "服務：\(clinic.services.joined(separator: "、"))"
                    ].joined(separator: "\n"),
                    authorId: snapshot.data()?["authorId"] as? String
                )
            case .review:
                let review = try decodeDocument(snapshot, as: Review.self)
                return ReportTargetSummary(
                    id: review.id,
                    type: .review,
                    title: review.title,
                    details: review.content,
                    authorId: review.userId
                )
            case .quote:
                let quote = try decodeDocument(snapshot, as: Quote.self)
                return ReportTargetSummary(
                    id: quote.id,
                    type: .quote,
                    title: quote.treatmentType,
                    details: [
                        "\(quote.currency) \(quote.estimatedCost)",
                        quote.notes
                    ].filter { !$0.isEmpty }.joined(separator: "\n"),
                    authorId: quote.userId
                )
            case .message:
                return nil
            }
        }

        switch report.targetType {
        case .clinic:
            guard let clinic = MockClinicRepository()
                .fetchClinics()
                .first(where: { $0.id == report.targetId }) else {
                return nil
            }
            return ReportTargetSummary(
                id: clinic.id,
                type: .clinic,
                title: clinic.name,
                details: [
                    clinic.address,
                    "電話：\(clinic.phone)",
                    "服務：\(clinic.services.joined(separator: "、"))"
                ].joined(separator: "\n"),
                authorId: nil
            )
        case .review, .quote, .message:
            return nil
        }
    }

    /// A take-down is one atomic batch: mark the public moderation state,
    /// remove a Firestore publication if one exists, and resolve the report.
    func resolveReport(id: String, takeDown: Bool) async throws {
        let db = try resolveFirestore()
        let identity = try authenticatedIdentity()
        guard try await isAdmin(uid: identity.uid) else { throw FirebaseError.adminRequired }

        let reportReference = db.collection("reports").document(id)
        let snapshot = try await reportReference.getDocument()
        guard snapshot.exists else { throw FirebaseError.documentNotFound(id) }
        let report = try decodeDocument(snapshot, as: Report.self)
        guard report.status == .pending else { throw FirebaseError.alreadyModerated }
        if takeDown, try await fetchCanonicalReportTarget(report) == nil {
            throw FirebaseError.invalidReportTarget
        }

        let batch = db.batch()
        if takeDown {
            if report.targetType == .message {
                guard let conversationId = report.conversationId else {
                    throw FirebaseError.invalidReportTarget
                }
                let conversationReference = db.collection("conversations")
                    .document(conversationId)
                let conversationSnapshot = try await conversationReference.getDocument()
                batch.updateData(
                    [
                        "body": "",
                        "isDeleted": true,
                        "deletedAt": FieldValue.serverTimestamp(),
                        "deletedBy": identity.uid
                    ],
                    forDocument: db.collection("conversations")
                        .document(conversationId)
                        .collection("messages")
                        .document(report.targetId)
                )
                if conversationSnapshot.data()?["lastMessageId"] as? String == report.targetId {
                    batch.updateData(
                        ["lastMessage": "訊息已刪除"],
                        forDocument: conversationReference
                    )
                }
            } else {
                let state = ContentModerationState(
                    id: contentStateID(type: report.targetType, targetId: report.targetId),
                    type: report.targetType,
                    targetId: report.targetId,
                    isRemoved: true,
                    isPinned: false,
                    updatedAt: Date(),
                    updatedBy: identity.uid
                )
                batch.setData(
                    try encoder.encode(state),
                    forDocument: db.collection("contentStates").document(state.id)
                )
                batch.deleteDocument(
                    db.collection(report.targetType.publicCollection).document(report.targetId)
                )
            }
        }
        batch.updateData(
            [
                "status": (takeDown ? ModerationStatus.approved : ModerationStatus.rejected).rawValue,
                "resolvedAt": FieldValue.serverTimestamp(),
                "resolvedBy": identity.uid
            ],
            forDocument: reportReference
        )
        try await batch.commit()
    }

    // MARK: - Public moderation state

    func fetchContentStates() async throws -> [ContentModerationState] {
        let snapshot = try await resolveFirestore().collection("contentStates").getDocuments()
        return try snapshot.documents.map { try decodeDocument($0, as: ContentModerationState.self) }
    }

    func setClinicPinned(clinicId: String, pinned: Bool) async throws {
        try await setContentState(type: .clinic, targetId: clinicId, isRemoved: nil, isPinned: pinned)
    }

    func setContentRemoved(type: ReportTargetType, targetId: String, removed: Bool) async throws {
        try await setContentState(type: type, targetId: targetId, isRemoved: removed, isPinned: nil)
    }

    // MARK: - User blocking

    func fetchBlockedUserIDs() async throws -> Set<String> {
        let identity = try authenticatedIdentity()
        let snapshot = try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .collection("blockedUsers")
            .getDocuments()
        return Set(snapshot.documents.map(\.documentID))
    }

    func blockUser(_ blockedUserId: String) async throws {
        let identity = try authenticatedIdentity()
        guard blockedUserId != identity.uid, !blockedUserId.isEmpty else {
            throw FirebaseError.cannotBlockSelf
        }
        try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .collection("blockedUsers")
            .document(blockedUserId)
            .setData([
                "blockedUserId": blockedUserId,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    func unblockUser(_ blockedUserId: String) async throws {
        let identity = try authenticatedIdentity()
        try await resolveFirestore()
            .collection("users")
            .document(identity.uid)
            .collection("blockedUsers")
            .document(blockedUserId)
            .delete()
    }

    // MARK: - Products / insurance

    func fetchProducts(category: String?) async throws -> [PetProduct] {
        let db = try resolveFirestore()
        let catalogExpiry = try await currentHKCatalogExpiry(in: db)
        let query = db.collection("products")
            .whereField("status", isEqualTo: ModerationStatus.approved.rawValue)
            .whereField("catalogRegion", isEqualTo: "HK")
            .whereField("region", isEqualTo: "HK")
            .whereField("expiresAt", isEqualTo: catalogExpiry)
        let snapshot = try await query.getDocuments()
        let products = try decodeFirestoreDocuments(
            snapshot.documents,
            documentID: \.documentID,
            decode: { document in
                let product = try self.decodeDocument(document, as: PetProduct.self)
                guard product.id == document.documentID,
                      SavedCatalogItems.kind(for: product.id) == .service else {
                    throw FirebaseError.catalogDocumentIdentityMismatch(document.documentID)
                }
                return product
            },
            onFailure: { documentID, error in
                CrashReporting.recordError(
                    error,
                    domain: "FirebaseService.fetchProducts.\(documentID)"
                )
            }
        )

        guard let category else { return products }
        return products.filter { $0.category == category }
    }

    func fetchInsurances() async throws -> [Insurance] {
        let db = try resolveFirestore()
        let catalogExpiry = try await currentHKCatalogExpiry(in: db)
        let snapshot = try await db
            .collection("insurances")
            .whereField("status", isEqualTo: ModerationStatus.approved.rawValue)
            .whereField("catalogRegion", isEqualTo: "HK")
            .whereField("region", isEqualTo: "HK")
            .whereField("expiresAt", isEqualTo: catalogExpiry)
            .getDocuments()
        return try decodeFirestoreDocuments(
            snapshot.documents,
            documentID: \.documentID,
            decode: { document in
                let plan = try self.decodeDocument(document, as: Insurance.self)
                guard plan.id == document.documentID,
                      SavedCatalogItems.kind(for: plan.id) == .insurance else {
                    throw FirebaseError.catalogDocumentIdentityMismatch(document.documentID)
                }
                return plan
            },
            onFailure: { documentID, error in
                CrashReporting.recordError(
                    error,
                    domain: "FirebaseService.fetchInsurances.\(documentID)"
                )
            }
        )
    }

    private func currentHKCatalogExpiry(in db: Firestore) async throws -> Timestamp {
        let anchor = try await db
            .collection("insurances")
            .document("insurance-hk-fwd")
            .getDocument()
        guard
            let data = anchor.data(),
            data["status"] as? String == ModerationStatus.approved.rawValue,
            data["catalogRegion"] as? String == "HK",
            data["region"] as? String == "HK",
            let expiry = data["expiresAt"] as? Timestamp,
            expiry.dateValue() > Date(timeIntervalSinceNow: 60)
        else {
            throw FirebaseError.invalidCatalog
        }
        return expiry
    }

    // MARK: - Roles

    func fetchUserRole(uid: String) async -> String? {
        guard let db = firestore else { return nil }
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            return document.data()?["role"] as? String
        } catch {
            CrashReporting.recordError(error, domain: "FirebaseService.fetchUserRole")
            return nil
        }
    }

    // MARK: - Private helpers

    private func saveSubmission(_ submission: ModerationSubmission) async throws {
        let data = try encoder.encode(submission)
        try await resolveFirestore()
            .collection("submissions")
            .document(submission.id)
            .setData(data)
    }

    private func publish(_ clinic: VetClinic, authorId: String) async throws {
        guard let publicClinic = ClinicPublicationPolicy.safeProjection(
            of: clinic,
            submitterID: authorId
        ) else {
            throw FirebaseError.invalidSubmission
        }
        try await resolveFirestore()
            .collection("clinics")
            .document(publicClinic.id)
            .setData(try publishedData(publicClinic, authorId: authorId, approvedAt: Date()))
    }

    private func publish(_ review: Review, authorId: String) async throws {
        try await resolveFirestore()
            .collection("reviews")
            .document(review.id)
            .setData(try publishedData(review, authorId: authorId, approvedAt: Date()))
    }

    private func publish(_ quote: Quote, authorId: String) async throws {
        try await resolveFirestore()
            .collection("quotes")
            .document(quote.id)
            .setData(try publishedData(quote, authorId: authorId, approvedAt: Date()))
    }

    private func publishedData<T: Encodable>(
        _ value: T,
        authorId: String,
        approvedAt: Date
    ) throws -> [String: Any] {
        var data = try encoder.encode(value)
        data["authorId"] = authorId
        data["status"] = ModerationStatus.approved.rawValue
        data["approvedAt"] = Timestamp(date: approvedAt)
        return data
    }

    private func setContentState(
        type: ReportTargetType,
        targetId: String,
        isRemoved: Bool?,
        isPinned: Bool?
    ) async throws {
        let db = try resolveFirestore()
        let identity = try authenticatedIdentity()
        guard try await isAdmin(uid: identity.uid) else { throw FirebaseError.adminRequired }

        let id = contentStateID(type: type, targetId: targetId)
        let reference = db.collection("contentStates").document(id)
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let current = try transaction.getDocument(reference)
                let existingRemoved = current.data()?["isRemoved"] as? Bool ?? false
                let existingPinned = current.data()?["isPinned"] as? Bool ?? false
                transaction.setData(
                    [
                        "id": id,
                        "type": type.rawValue,
                        "targetId": targetId,
                        "isRemoved": isRemoved ?? existingRemoved,
                        "isPinned": isPinned ?? existingPinned,
                        "updatedAt": Timestamp(date: Date()),
                        "updatedBy": identity.uid
                    ],
                    forDocument: reference
                )
                return nil
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }
    }

    private func contentStateID(type: ReportTargetType, targetId: String) -> String {
        "\(type.rawValue)-\(targetId)"
    }

    private func isSafeDocumentID(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 200
            && !value.contains("/")
            && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
    }

    private func isAdmin(uid: String) async throws -> Bool {
        let document = try await resolveFirestore().collection("users").document(uid).getDocument()
        return document.data()?["role"] as? String == "admin"
    }

    private func authenticatedIdentity() throws -> (uid: String, name: String) {
        #if canImport(FirebaseAuth)
        guard FirebaseApp.app() != nil, let user = Auth.auth().currentUser else {
            throw FirebaseError.authenticationRequired
        }
        let displayName = user.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (user.uid, (displayName?.isEmpty == false ? displayName : nil) ?? "VetMap 用戶")
        #else
        throw FirebaseError.authenticationRequired
        #endif
    }

    private func resolveFirestore() throws -> Firestore {
        guard let db = firestore else {
            throw FirebaseError.notConfigured
        }
        return db
    }

    private func decodeDocument<T: Decodable>(
        _ document: DocumentSnapshot,
        as type: T.Type
    ) throws -> T {
        do {
            return try document.data(as: type)
        } catch {
            throw FirebaseError.decodingFailed(error)
        }
    }
}
#endif

enum FirebaseError: Error {
    case notConfigured
    case authenticationRequired
    case adminRequired
    case requiresModeration
    case documentNotFound(String)
    case invalidSubmission
    case alreadyModerated
    case publicDocumentConflict
    case invalidReportTarget
    case invalidReviewID
    case invalidFavoriteClinicID
    case invalidSavedCatalogItemID
    case authenticationStateChanged
    case catalogDocumentIdentityMismatch(String)
    case cannotBlockSelf
    case invalidCatalog
    case encodingFailed(Error)
    case decodingFailed(Error)
}

extension FirebaseError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Firebase 尚未設定，無法連接雲端服務。"
        case .authenticationRequired:
            "請先登入 Firebase 帳戶再提交。"
        case .adminRequired:
            "只有管理員可以執行這項審核操作。"
        case .requiresModeration:
            "此內容必須先提交審核，不能直接公開。"
        case .documentNotFound(let id):
            "找不到文件：\(id)"
        case .invalidSubmission:
            "投稿資料不完整，無法審核。"
        case .alreadyModerated:
            "這項內容已由其他管理員處理。"
        case .publicDocumentConflict:
            "投稿的公開識別碼與現有內容重複，已停止批准以免覆寫資料。"
        case .invalidReportTarget:
            "找不到舉報所指的原始內容，已停止下架以免誤刪資料。"
        case .invalidReviewID:
            "評價識別碼無效，未能標記為有用。"
        case .invalidFavoriteClinicID:
            "診所識別碼無效，未能更新收藏。"
        case .invalidSavedCatalogItemID:
            String(localized: "服務或保險識別碼無效，未能更新收藏。")
        case .authenticationStateChanged:
            String(localized: "登入帳戶已變更，請重新操作。")
        case .catalogDocumentIdentityMismatch(let id):
            String(localized: "目錄文件識別碼不一致：\(id)")
        case .cannotBlockSelf:
            "不能封鎖自己的帳戶。"
        case .invalidCatalog:
            "香港商戶目錄尚未準備好或已過期。"
        case .encodingFailed(let error):
            "資料編碼失敗：\(error.localizedDescription)"
        case .decodingFailed(let error):
            "資料解碼失敗：\(error.localizedDescription)"
        }
    }
}
