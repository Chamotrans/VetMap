import Foundation

struct ChatTarget: Identifiable, Hashable {
    let userID: String
    let displayName: String

    var id: String { userID }
}

struct ChatConversation: Identifiable, Codable, Equatable {
    let id: String
    var participantIds: [String]
    var participantNames: [String: String]
    var lastMessageId: String
    var lastMessage: String
    var lastMessageAt: Date
    var lastSenderId: String
    var createdAt: Date
    var updatedAt: Date

    func otherUserID(for currentUserID: String) -> String? {
        participantIds.first { $0 != currentUserID }
    }

    func otherDisplayName(for currentUserID: String) -> String {
        guard let otherID = otherUserID(for: currentUserID) else { return "VetMap 用戶" }
        let name = participantNames[otherID]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name?.isEmpty == false ? name! : "VetMap 用戶"
    }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    var conversationId: String
    var senderId: String
    var body: String
    var sentAt: Date
    var isDeleted: Bool
    var deletedAt: Date?
    var deletedBy: String?
}

enum ChatConversationID {
    static func make(_ firstUserID: String, _ secondUserID: String) -> String? {
        let users = [firstUserID, secondUserID]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()
        guard users.count == 2,
              users[0] != users[1],
              users.allSatisfy(isSafeUserID) else {
            return nil
        }
        let conversationID = users.joined(separator: "--")
        return conversationID.count <= 200 ? conversationID : nil
    }

    private static func isSafeUserID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 100 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}
