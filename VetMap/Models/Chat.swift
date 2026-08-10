import Foundation

struct ChatTarget: Identifiable, Hashable {
    let userID: String
    let displayName: String
    let sourceReviewID: String?

    init(userID: String, displayName: String, sourceReviewID: String? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.sourceReviewID = sourceReviewID
    }

    var id: String { userID }
}

struct ChatConversation: Identifiable, Codable, Equatable {
    let id: String
    var participantIds: [String]
    var participantNames: [String: String]
    var sourceReviewId: String? = nil
    var lastMessageId: String
    var lastMessage: String
    var lastMessageAt: Date
    var lastSenderId: String
    var createdAt: Date
    var updatedAt: Date

    func otherUserID(for currentUserID: String) -> String? {
        let currentID = currentUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentID.isEmpty,
              participantIds.count == 2,
              Set(participantIds).count == 2,
              participantIds.contains(currentID) else {
            return nil
        }
        return participantIds.first { $0 != currentID }
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

/// Firestore reads the newest message window in descending order so long
/// conversations do not lose recent replies. Presentation remains oldest to
/// newest within that bounded window.
enum ChatMessageWindow {
    static let maximumCount = 200
    static let fetchesNewestFirst = true

    static func chronological(_ messages: [ChatMessage]) -> [ChatMessage] {
        messages.sorted {
            if $0.sentAt == $1.sentAt {
                return $0.id < $1.id
            }
            return $0.sentAt < $1.sentAt
        }
    }
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

    static func isSafeDocumentID(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.count <= 200,
              let first = value.unicodeScalars.first,
              CharacterSet.alphanumerics.contains(first) else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static func isSafeUserID(_ value: String) -> Bool {
        value.count <= 100 && isSafeDocumentID(value)
    }
}
