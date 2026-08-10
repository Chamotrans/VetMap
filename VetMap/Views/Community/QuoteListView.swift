import SwiftUI

struct QuoteListView: View {
    let clinicId: String
    let clinicName: String

    @ObservedObject private var auth = AuthViewModel.shared
    @State private var viewModel: QuoteViewModel
    @State private var isAddingQuote = false
    @State private var showLogin = false
    @State private var didAuthenticateDuringLogin = false
    @State private var actionContinuation =
        AuthenticatedActionContinuation<PendingAction>()
    @State private var destructiveConfirmation: DestructiveAction?

    private enum PendingAction: Equatable {
        case addQuote
        case confirm(DestructiveAction)
    }

    private enum DestructiveAction: Equatable {
        case report(Quote, reason: String)
        case block(Quote)
    }

    init(clinicId: String, clinicName: String) {
        self.clinicId = clinicId
        self.clinicName = clinicName
        _viewModel = State(
            wrappedValue: QuoteViewModel(clinicId: clinicId, clinicName: clinicName)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let error = viewModel.storageError {
                    Label(error, systemImage: "externaldrive.badge.exclamationmark")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.warning)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard(fill: AppTheme.warning.opacity(0.12), stroke: AppTheme.warning.opacity(0.22))
                }

                if viewModel.visibleQuotes.isEmpty {
                    emptyState
                } else {
                    ForEach(viewModel.visibleQuotes) { quote in
                        quoteCard(quote)
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.screenBackground)
        .refreshable {
            await viewModel.loadQuotes()
        }
        .navigationTitle("\(clinicName) 費用報價")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    requestAuthenticatedAction(.addQuote)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新增報價")
            }
        }
        .sheet(isPresented: $isAddingQuote) {
            AddQuoteView(viewModel: viewModel)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.largeTitle)
                .foregroundStyle(AppTheme.primary)
                .accessibilityHidden(true)

            Text("尚無報價記錄，成為第一個分享的吧！")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .appCard()
    }

    private func quoteCard(_ quote: Quote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text("💉")
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.treatmentType)
                        .font(.subheadline.weight(.semibold))

                    costSummary(quote)
                }

                Spacer()

                Text(quote.currency)
                    .appChip(
                        tint: quote.currency == "TWD" ? AppTheme.primary : AppTheme.accent,
                        isFilled: true
                    )

                Menu {
                    ForEach(["資料不實", "冒犯內容", "廣告或垃圾訊息", "其他"], id: \.self) { reason in
                        Button {
                            requestAuthenticatedAction(
                                .confirm(.report(quote, reason: reason))
                            )
                        } label: {
                            Text("舉報：\(reason)")
                        }
                    }
                    Button(role: .destructive) {
                        requestAuthenticatedAction(.confirm(.block(quote)))
                    } label: {
                        Label("封鎖作者", systemImage: "person.crop.circle.badge.xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.tertiary)
                }
            }

            if !quote.notes.isEmpty {
                Text(quote.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Text(quote.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .environment(\.locale, Locale(identifier: "zh_Hant"))
            }
        }
        .padding(14)
        .appCard()
    }

    @ViewBuilder
    private func costSummary(_ quote: Quote) -> some View {
        if let actualCost = quote.actualCost, actualCost != quote.estimatedCost {
            Text("預估 \(costText(quote.estimatedCost, currency: quote.currency)) → 實際 \(costText(actualCost, currency: quote.currency))")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let actualCost = quote.actualCost {
            Text(costText(actualCost, currency: quote.currency))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("預估 \(costText(quote.estimatedCost, currency: quote.currency))（尚未治療）")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func costText(_ amount: Decimal, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let number = NSDecimalNumber(decimal: amount)
        let symbol = currency == "TWD" ? "NT$" : "HK$"
        return "\(symbol)\(formatter.string(from: number) ?? number.stringValue)"
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
        case .addQuote:
            isAddingQuote = true
        case .confirm(let destructiveAction):
            // A destructive action is never resumed straight into a write.
            // Login success only brings the user back to this confirmation.
            destructiveConfirmation = destructiveAction
        }
    }

    private var destructiveConfirmationTitle: String {
        switch destructiveConfirmation {
        case .report:
            return String(localized: "確認舉報此報價？")
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
            // The session may expire while the dialog is open. Re-authenticate,
            // then show the confirmation again instead of writing immediately.
            requestAuthenticatedAction(.confirm(action))
            return
        }

        switch action {
        case .report(let quote, let reason):
            Task { _ = await viewModel.report(quote, reason: reason) }
        case .block(let quote):
            Task { _ = await viewModel.blockAuthor(of: quote) }
        }
    }
}

#Preview {
    NavigationStack {
        QuoteListView(clinicId: "debug-clinic", clinicName: "VetMap 測試診所")
    }
}
