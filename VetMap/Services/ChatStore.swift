import Combine
import Foundation

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ChatStore: ObservableObject {
    static let shared = ChatStore()

    @Published private(set) var conversations: [ChatConversation] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var observedConversationID: String?

    private var firestore: Firestore? {
        guard FirebaseApp.app() != nil else { return nil }
        return Firestore.firestore()
    }

    private var currentUser: User? {
        guard FirebaseApp.app() != nil else { return nil }
        return Auth.auth().currentUser
    }

    func observeConversations() {
        stopObservingConversations()
        guard let db = firestore, let uid = currentUser?.uid else {
            conversations = []
            errorMessage = nil
            return
        }

        isLoading = true
        conversationsListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: uid)
            .order(by: "updatedAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let error {
                        record(error, domain: "ChatStore.observeConversations")
                        return
                    }
                    do {
                        conversations = try snapshot?.documents.compactMap {
                            try $0.data(as: ChatConversation.self)
                        } ?? []
                        errorMessage = nil
                    } catch {
                        record(error, domain: "ChatStore.decodeConversations")
                    }
                }
            }
    }

    func stopObservingConversations() {
        conversationsListener?.remove()
        conversationsListener = nil
    }

    func observeMessages(conversationID: String) {
        guard observedConversationID != conversationID || messagesListener == nil else { return }
        stopObservingMessages()
        guard let db = firestore, currentUser != nil else {
            messages = []
            return
        }

        observedConversationID = conversationID
        isLoading = true
        messagesListener = db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "sentAt")
            .limit(to: 200)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    isLoading = false
                    if let error {
                        record(error, domain: "ChatStore.observeMessages")
                        return
                    }
                    do {
                        messages = try snapshot?.documents.compactMap {
                            try $0.data(as: ChatMessage.self)
                        } ?? []
                        errorMessage = nil
                    } catch {
                        record(error, domain: "ChatStore.decodeMessages")
                    }
                }
            }
    }

    func stopObservingMessages() {
        messagesListener?.remove()
        messagesListener = nil
        observedConversationID = nil
        messages = []
    }

    func send(
        body originalBody: String,
        conversationID: String?,
        recipient: ChatTarget
    ) async throws -> String {
        guard let db = firestore, let user = currentUser else {
            throw FirebaseError.authenticationRequired
        }
        let body = originalBody.trimmingCharacters(in: .whitespacesAndNewlines)
        try ContentSafety.validate([body], maximumLength: 1_000)
        guard let canonicalID = ChatConversationID.make(user.uid, recipient.userID),
              conversationID == nil || conversationID == canonicalID else {
            throw ChatError.invalidRecipient
        }

        isSending = true
        defer { isSending = false }

        let now = Date()
        let messageID = db.collection("conversations")
            .document(canonicalID)
            .collection("messages")
            .document().documentID
        let message = ChatMessage(
            id: messageID,
            conversationId: canonicalID,
            senderId: user.uid,
            body: body,
            sentAt: now,
            isDeleted: false
        )
        let conversationReference = db.collection("conversations").document(canonicalID)
        let messageReference = conversationReference.collection("messages").document(messageID)
        let existingConversations = try await db.collection("conversations")
            .whereField("participantIds", arrayContains: user.uid)
            .getDocuments()
        let conversationExists = existingConversations.documents.contains {
            $0.documentID == canonicalID
        }
        let batch = db.batch()

        if conversationExists {
            batch.updateData([
                "lastMessageId": messageID,
                "lastMessage": body,
                "lastMessageAt": Timestamp(date: now),
                "lastSenderId": user.uid,
                "updatedAt": Timestamp(date: now)
            ], forDocument: conversationReference)
        } else {
            let senderName = normalizedName(user.displayName)
            let recipientName = normalizedName(recipient.displayName)
            let participants = [user.uid, recipient.userID].sorted()
            let conversation = ChatConversation(
                id: canonicalID,
                participantIds: participants,
                participantNames: [
                    user.uid: senderName,
                    recipient.userID: recipientName
                ],
                lastMessageId: messageID,
                lastMessage: body,
                lastMessageAt: now,
                lastSenderId: user.uid,
                createdAt: now,
                updatedAt: now
            )
            batch.setData(try Firestore.Encoder().encode(conversation), forDocument: conversationReference)
        }
        batch.setData(try Firestore.Encoder().encode(message), forDocument: messageReference)

        do {
            try await batch.commit()
            errorMessage = nil
            return canonicalID
        } catch {
            record(error, domain: "ChatStore.send")
            throw error
        }
    }

    func deleteMessage(_ message: ChatMessage) async throws {
        guard let db = firestore, let uid = currentUser?.uid else {
            throw FirebaseError.authenticationRequired
        }
        guard message.senderId == uid, !message.isDeleted else {
            throw ChatError.cannotDeleteMessage
        }
        do {
            let conversationReference = db.collection("conversations")
                .document(message.conversationId)
            let messageReference = conversationReference.collection("messages")
                .document(message.id)
            let conversation = try await conversationReference.getDocument()
            let batch = db.batch()
            batch.updateData([
                    "body": "",
                    "isDeleted": true,
                    "deletedAt": FieldValue.serverTimestamp(),
                    "deletedBy": uid
                ], forDocument: messageReference)
            if conversation.data()?["lastMessageId"] as? String == message.id {
                batch.updateData(["lastMessage": "訊息已刪除"], forDocument: conversationReference)
            }
            try await batch.commit()
            errorMessage = nil
        } catch {
            record(error, domain: "ChatStore.deleteMessage")
            throw error
        }
    }

    func reportMessage(_ message: ChatMessage, reason: String) async throws {
        try await ModerationStore.shared.submitReport(
            targetType: .message,
            targetId: message.id,
            targetTitle: "聊天室訊息",
            clinicId: nil,
            conversationId: message.conversationId,
            reason: reason
        )
    }

    func block(_ userID: String) async throws {
        try await ModerationStore.shared.blockUser(userID)
        conversations.removeAll { $0.participantIds.contains(userID) }
    }

    private func normalizedName(_ value: String?) -> String {
        let name = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "VetMap 用戶" : String(name.prefix(80))
    }

    private func record(_ error: Error, domain: String) {
        errorMessage = error.localizedDescription
        CrashReporting.recordError(error, domain: domain)
    }
}

#else
@MainActor
final class ChatStore: ObservableObject {
    static let shared = ChatStore()
    @Published private(set) var conversations: [ChatConversation] = []
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    func observeConversations() {}
    func stopObservingConversations() {}
    func observeMessages(conversationID: String) {}
    func stopObservingMessages() {}
    func send(body: String, conversationID: String?, recipient: ChatTarget) async throws -> String {
        throw FirebaseError.notConfigured
    }
    func deleteMessage(_ message: ChatMessage) async throws { throw FirebaseError.notConfigured }
    func reportMessage(_ message: ChatMessage, reason: String) async throws { throw FirebaseError.notConfigured }
    func block(_ userID: String) async throws { throw FirebaseError.notConfigured }
}
#endif

enum ChatError: LocalizedError {
    case invalidRecipient
    case cannotDeleteMessage

    var errorDescription: String? {
        switch self {
        case .invalidRecipient: "無法建立此對話。"
        case .cannotDeleteMessage: "只可刪除自己發出的訊息。"
        }
    }
}
