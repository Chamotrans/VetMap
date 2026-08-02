import SwiftUI

struct ChatThreadView: View {
    @ObservedObject private var auth = AuthViewModel.shared
    @ObservedObject private var chat = ChatStore.shared

    let target: ChatTarget
    @State private var conversationID: String?
    @State private var draft = ""
    @State private var selectedReportMessage: ChatMessage?
    @State private var showReportReasons = false
    @State private var showBlockConfirmation = false
    @State private var didBlock = false
    @State private var notice: String?
    @Environment(\.dismiss) private var dismiss

    init(conversation: ChatConversation? = nil, target: ChatTarget) {
        self.target = target
        _conversationID = State(initialValue: conversation?.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            safetyBanner
            messagesView
            composer
        }
        .navigationTitle(target.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showBlockConfirmation = true
                    } label: {
                        Label("封鎖用戶", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("對話操作")
            }
        }
        .onAppear {
            if let conversationID {
                chat.observeMessages(conversationID: conversationID)
            }
        }
        .onDisappear {
            chat.stopObservingMessages()
        }
        .confirmationDialog(
            "舉報此訊息",
            isPresented: $showReportReasons,
            titleVisibility: .visible
        ) {
            ForEach(["騷擾或冒犯", "仇恨或危險內容", "廣告或詐騙", "不實內容", "其他"], id: \.self) { reason in
                Button(reason) {
                    submitReport(reason: reason)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("舉報會交由 VetMap 管理員審核。")
        }
        .alert("封鎖 (target.displayName)？", isPresented: $showBlockConfirmation) {
            Button("取消", role: .cancel) {}
            Button("封鎖", role: .destructive) {
                blockUser()
            }
        } message: {
            Text("封鎖後，雙方不能再互傳新訊息；此對話亦會從你的訊息列表隱藏。")
        }
        .alert("聊天室", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("好", role: .cancel) {
                if didBlock { dismiss() }
            }
        } message: {
            Text(notice ?? "")
        }
    }

    private var safetyBanner: some View {
        Label("請勿分享密碼、信用卡或醫療緊急資料；緊急情況請直接聯絡診所。", systemImage: "shield.checkered")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(AppTheme.warning.opacity(0.10))
    }

    @ViewBuilder
    private var messagesView: some View {
        if conversationID == nil {
            ContentUnavailableView {
                Label("開始對話", systemImage: "bubble.left")
            } description: {
                Text("向 (target.displayName) 傳送第一則訊息。")
            }
            .frame(maxHeight: .infinity)
        } else if chat.isLoading && chat.messages.isEmpty {
            ProgressView("載入訊息…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(chat.messages) { message in
                            messageRow(message)
                                .id(message.id)
                        }
                    }
                    .padding(14)
                }
                .background(AppTheme.screenBackground)
                .onChange(of: chat.messages.count) { _, _ in
                    if let lastID = chat.messages.last?.id {
                        withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private func messageRow(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == auth.user?.uid
        return HStack {
            if isMine { Spacer(minLength: 54) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                Text(message.isDeleted ? "訊息已刪除" : message.body)
                    .font(.body)
                    .foregroundStyle(message.isDeleted ? .secondary : (isMine ? .white : .primary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        message.isDeleted
                            ? Color(.tertiarySystemFill)
                            : (isMine ? AppTheme.primary : Color(.secondarySystemGroupedBackground)),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                Text(message.sentAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .contextMenu {
                if !message.isDeleted {
                    if isMine {
                        Button(role: .destructive) {
                            deleteMessage(message)
                        } label: {
                            Label("刪除訊息", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            selectedReportMessage = message
                            showReportReasons = true
                        } label: {
                            Label("舉報訊息", systemImage: "flag")
                        }
                    }
                }
            }

            if !isMine { Spacer(minLength: 54) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("輸入訊息", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(
                draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || draft.count > 1_000
                    || chat.isSending
            )
            .accessibilityLabel("傳送訊息")
        }
        .padding(12)
        .background(.bar)
    }

    private func send() {
        let body = draft
        draft = ""
        Task {
            do {
                let id = try await chat.send(
                    body: body,
                    conversationID: conversationID,
                    recipient: target
                )
                if conversationID == nil {
                    conversationID = id
                    chat.observeMessages(conversationID: id)
                }
                Haptics.success()
            } catch {
                draft = body
                notice = error.localizedDescription
            }
        }
    }

    private func deleteMessage(_ message: ChatMessage) {
        Task {
            do {
                try await chat.deleteMessage(message)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func submitReport(reason: String) {
        guard let message = selectedReportMessage else { return }
        selectedReportMessage = nil
        Task {
            do {
                try await chat.reportMessage(message, reason: reason)
                notice = "舉報已送出，管理員會盡快審核。"
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func blockUser() {
        Task {
            do {
                try await chat.block(target.userID)
                didBlock = true
                notice = "已封鎖 (target.displayName)。"
            } catch {
                notice = error.localizedDescription
            }
        }
    }
}
