import SwiftUI

struct ReviewListView: View {
    let clinic: VetClinic

    @ObservedObject private var auth = AuthViewModel.shared
    @State private var viewModel: ReviewViewModel
    @State private var chatTarget: ChatTarget?
    @State private var showLogin = false
    @State private var didAuthenticateDuringLogin = false
    @State private var actionContinuation =
        AuthenticatedActionContinuation<PendingAction>()
    @State private var destructiveConfirmation: DestructiveAction?

    private enum PendingAction: Equatable {
        case markHelpful(reviewID: String)
        case message(ChatTarget)
        case confirm(DestructiveAction)
    }

    private enum DestructiveAction: Equatable {
        case report(Review, reason: String)
        case block(Review)
    }

    init(clinic: VetClinic) {
        self.clinic = clinic
        _viewModel = State(wrappedValue: ReviewViewModel(clinicId: clinic.id))
    }

    private let currency = "HKD"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sortPicker

                if let error = viewModel.storageError {
                    Label(error, systemImage: "icloud.slash")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.warning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard(
                            fill: AppTheme.warning.opacity(0.12),
                            stroke: AppTheme.warning.opacity(0.22)
                        )
                }

                if viewModel.sortedReviews.isEmpty {
                    emptyState
                } else {
                    reviewCountSummary

                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.sortedReviews) { review in
                            ReviewRowView(
                                review: review,
                                currency: currency,
                                onMarkHelpful: {
                                    requestAuthenticatedAction(
                                        .markHelpful(reviewID: review.id)
                                    )
                                },
                                onReport: { reason in
                                    requestAuthenticatedAction(
                                        .confirm(.report(review, reason: reason))
                                    )
                                },
                                onBlockAuthor: {
                                    requestAuthenticatedAction(.confirm(.block(review)))
                                },
                                onMessageAuthor: canOfferMessage(review) ? {
                                    requestAuthenticatedAction(
                                        .message(
                                            ChatTarget(
                                                userID: review.userId,
                                                displayName: review.userName,
                                                sourceReviewID: review.id
                                            )
                                        )
                                    )
                                } : nil
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground)
        .refreshable {
            await viewModel.loadReviews()
        }
        .navigationTitle("\(clinic.name) 評價")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $chatTarget) { target in
            ChatThreadView(target: target)
        }
        .confirmationDialog(
            destructiveConfirmationTitle,
            isPresented: Binding(
                get: { destructiveConfirmation != nil },
                set: { if !$0 { destructiveConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let action = destructiveConfirmation {
                Button(destructiveConfirmationButtonTitle(for: action), role: .destructive) {
                    destructiveConfirmation = nil
                    executeConfirmed(action)
                }
            }
            Button("取消", role: .cancel) {
                destructiveConfirmation = nil
            }
        }
        .fullScreenCover(isPresented: $showLogin, onDismiss: loginDidDismiss) {
            LoginView(authViewModel: auth)
        }
        .onChange(of: auth.authState) { _, _ in
            authenticationDidChange()
        }
        .onChange(of: auth.user?.uid) { _, _ in
            authenticationDidChange()
        }
    }

    private func canOfferMessage(_ review: Review) -> Bool {
        let userID = review.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userID.isEmpty else { return false }
        return userID != auth.user?.uid
            && !ModerationStore.shared.blockedUserIDs.contains(review.userId)
    }

    private var sortPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("排序方式")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Picker("排序", selection: $viewModel.sortOrder) {
                ForEach(ReviewSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .appCard()
    }

    private var reviewCountSummary: some View {
        HStack {
            Label("共 \(viewModel.sortedReviews.count) 則評價", systemImage: "text.bubble.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.title)
                .foregroundStyle(AppTheme.primary)
                .frame(width: 56, height: 56)
                .background(
                    AppTheme.primary.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                )

            Text("暫無評價")
                .font(.headline)

            Text("成為第一位分享經驗的寵物主人")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private var authenticationPhase: CommunityAuthenticationPhase {
        switch auth.authState {
        case .loading:
            return .loading
        case .signedOut:
            return .signedOut
        case .signedIn:
            guard let userID = auth.user?.uid, !userID.isEmpty else { return .loading }
            return .signedIn(userID: userID)
        }
    }

    private func requestAuthenticatedAction(_ action: PendingAction) {
        handle(actionContinuation.request(action, authentication: authenticationPhase))
    }

    private func handle(_ request: AuthenticatedActionRequest<PendingAction>) {
        switch request {
        case .perform(let action):
            perform(action)
        case .waitForAuthentication:
            break
        case .presentLogin:
            presentLogin()
        }
    }

    private func authenticationDidChange() {
        guard actionContinuation.hasPendingAction else { return }
        switch authenticationPhase {
        case .loading:
            break
        case .signedOut:
            presentLogin()
        case .signedIn:
            if showLogin {
                didAuthenticateDuringLogin = true
                showLogin = false
            } else {
                resumeAfterLogin()
            }
        }
    }

    private func presentLogin() {
        if !showLogin {
            didAuthenticateDuringLogin = false
        }
        showLogin = true
    }

    private func loginDidDismiss() {
        guard didAuthenticateDuringLogin else {
            actionContinuation.cancel()
            return
        }
        didAuthenticateDuringLogin = false
        resumeAfterLogin()
    }

    private func resumeAfterLogin() {
        guard let action = actionContinuation.takeIfAuthenticated(authenticationPhase) else {
            if authenticationPhase == .signedOut {
                actionContinuation.cancel()
            }
            return
        }
        perform(action)
    }

    private func perform(_ action: PendingAction) {
        switch action {
        case .markHelpful(let reviewID):
            Task { await viewModel.markHelpful(reviewID) }
        case .message(let target):
            guard let currentUserID = authenticationPhase.authenticatedUserID,
                  target.userID != currentUserID,
                  !ModerationStore.shared.blockedUserIDs.contains(target.userID) else {
                return
            }
            chatTarget = target
        case .confirm(let destructiveAction):
            // Authentication only restores the pending confirmation. It never
            // turns a report or block gesture into an immediate backend write.
            destructiveConfirmation = destructiveAction
        }
    }

    private var destructiveConfirmationTitle: String {
        switch destructiveConfirmation {
        case .report:
            return String(localized: "確認舉報此評價？")
        case .block:
            return String(localized: "確認封鎖此作者？")
        case nil:
            return String(localized: "確認操作")
        }
    }

    private func destructiveConfirmationButtonTitle(for action: DestructiveAction) -> String {
        switch action {
        case .report:
            return String(localized: "確認舉報")
        case .block:
            return String(localized: "確認封鎖")
        }
    }

    private func executeConfirmed(_ action: DestructiveAction) {
        guard authenticationPhase.authenticatedUserID != nil else {
            requestAuthenticatedAction(.confirm(action))
            return
        }

        switch action {
        case .report(let review, let reason):
            Task { _ = await viewModel.report(review, reason: reason) }
        case .block(let review):
            Task { _ = await viewModel.blockAuthor(of: review) }
        }
    }
}

#Preview {
    NavigationStack {
        ReviewListView(clinic: MockClinicRepository.hkClinics[0])
    }
}
