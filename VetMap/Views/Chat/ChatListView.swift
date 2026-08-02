import SwiftUI

struct ChatListView: View {
    @ObservedObject private var auth = AuthViewModel.shared
    @ObservedObject private var chat = ChatStore.shared
    @ObservedObject private var moderation = ModerationStore.shared
    @State private var showLogin = false

    private var currentUserID: String? { auth.user?.uid }

    private var visibleConversations: [ChatConversation] {
        guard let currentUserID else { return [] }
        return chat.conversations.filter { conversation in
            guard let otherID = conversation.otherUserID(for: currentUserID) else { return false }
            return !moderation.blockedUserIDs.contains(otherID)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch auth.authState {
                case .loading:
                    ProgressView("載入訊息…")
                case .signedOut:
                    signedOutView
                case .signedIn:
                    signedInView
                }
            }
            .navigationTitle("訊息")
            .background(AppTheme.screenBackground)
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(authViewModel: auth)
        }
        .onAppear {
            startIfSignedIn()
        }
        .onDisappear {
            chat.stopObservingConversations()
        }
        .onChange(of: auth.authState) { _, _ in
            startIfSignedIn()
        }
    }

    private var signedOutView: some View {
        ContentUnavailableView {
            Label("登入後使用聊天室", systemImage: "bubble.left.and.bubble.right.fill")
        } description: {
            Text("同社群評價作者私下交流；你可以隨時舉報訊息或封鎖對方。")
        } actions: {
            Button("登入 / 註冊") {
                showLogin = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
    }

    @ViewBuilder
    private var signedInView: some View {
        if chat.isLoading && chat.conversations.isEmpty {
            ProgressView("載入對話…")
        } else if visibleConversations.isEmpty {
            ContentUnavailableView {
                Label("未有對話", systemImage: "bubble.left.and.bubble.right")
            } description: {
                Text("你可在診所評價的操作選單選擇「傳送訊息」開始對話。")
            }
        } else {
            List(visibleConversations) { conversation in
                if let target = target(for: conversation) {
                    NavigationLink {
                        ChatThreadView(conversation: conversation, target: target)
                    } label: {
                        conversationRow(conversation, target: target)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                chat.observeConversations()
                await moderation.refreshPublicState()
            }
        }
    }

    private func conversationRow(_ conversation: ChatConversation, target: ChatTarget) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(AppTheme.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(target.displayName)
                    .font(.headline)
                    .lineLimit(1)

                Text(conversation.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(conversation.lastMessageAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func target(for conversation: ChatConversation) -> ChatTarget? {
        guard let currentUserID,
              let otherID = conversation.otherUserID(for: currentUserID) else {
            return nil
        }
        return ChatTarget(
            userID: otherID,
            displayName: conversation.otherDisplayName(for: currentUserID)
        )
    }

    private func startIfSignedIn() {
        if auth.authState == .signedIn {
            chat.observeConversations()
            Task { await moderation.refreshPublicState() }
        } else {
            chat.stopObservingConversations()
        }
    }
}
