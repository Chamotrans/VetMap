import Foundation

@main
enum ChatOriginHarness {
    static func main() throws {
        precondition(
            ChatConversationID.make("bob", "alice") == "alice--bob",
            "conversation IDs must use canonical participant order"
        )
        precondition(
            ChatConversationID.make("alice", "alice") == nil,
            "self conversations must remain invalid"
        )
        precondition(
            ChatConversationID.isSafeDocumentID("review-1"),
            "valid source review IDs must be accepted"
        )
        precondition(
            !ChatConversationID.isSafeDocumentID("-review"),
            "source review IDs must start with an alphanumeric character"
        )

        let timestamp = Date(timeIntervalSince1970: 1_718_000_000)
        let conversation = ChatConversation(
            id: "alice--bob",
            participantIds: ["alice", "bob"],
            participantNames: ["alice": "Alice", "bob": "Bob"],
            sourceReviewId: "review-1",
            lastMessageId: "message-1",
            lastMessage: "你好",
            lastMessageAt: timestamp,
            lastSenderId: "alice",
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let encoded = try encoder.encode(conversation)
        let decoded = try decoder.decode(ChatConversation.self, from: encoded)
        precondition(
            decoded.sourceReviewId == "review-1",
            "source review linkage must survive Codable round-trip"
        )

        var legacyObject = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        legacyObject.removeValue(forKey: "sourceReviewId")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject)
        let legacy = try decoder.decode(ChatConversation.self, from: legacyData)
        precondition(
            legacy.sourceReviewId == nil,
            "legacy conversations without sourceReviewId must remain decodable"
        )

        precondition(
            conversation.otherUserID(for: "mallory") == nil,
            "a non-participant must never resolve another user's identity"
        )
        var malformedConversation = conversation
        malformedConversation.participantIds = ["alice", "alice"]
        precondition(
            malformedConversation.otherUserID(for: "alice") == nil,
            "duplicate participant IDs must fail closed"
        )

        let olderMessage = ChatMessage(
            id: "message-old",
            conversationId: conversation.id,
            senderId: "alice",
            body: "舊訊息",
            sentAt: timestamp.addingTimeInterval(-60),
            isDeleted: false
        )
        let newerMessage = ChatMessage(
            id: "message-new",
            conversationId: conversation.id,
            senderId: "bob",
            body: "新訊息",
            sentAt: timestamp,
            isDeleted: false
        )
        precondition(
            ChatMessageWindow.fetchesNewestFirst
                && ChatMessageWindow.maximumCount == 200,
            "the Firestore window must fetch the newest 200 messages"
        )
        precondition(
            ChatMessageWindow.chronological([newerMessage, olderMessage])
                .map(\.id) == ["message-old", "message-new"],
            "the newest window must be presented chronologically"
        )

        print(
            "chatOrigin: true; legacyConversationCompatible: true; "
                + "participantIsolation: true; newestWindow: 200"
        )
    }
}
