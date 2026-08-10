import SwiftUI

struct AddReviewView: View {
    let clinicName: String
    var onSubmit: (ReviewDraft) async -> CommunitySubmissionResult

    @ObservedObject private var auth = AuthViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var rating = 5
    @State private var title = ""
    @State private var content = ""
    @State private var treatmentType = "一般診療"
    @State private var cost = ""
    @State private var validationMessage: String?
    @State private var isSubmitting = false
    @State private var showLogin = false
    @State private var didAuthenticateDuringLogin = false
    @State private var submissionContinuation =
        AuthenticatedActionContinuation<ReviewDraft>()

    @State private var showConfetti = false

    private let treatmentTypes = [
        "疫苗接種", "一般診療", "外科手術", "牙科",
        "皮膚科", "影像檢查", "夜間門診", "初診", "其他"
    ]

    private enum Field: Hashable {
        case title
        case content
        case cost
    }

    var body: some View {
        NavigationStack {
            Form {
                ratingSection
                contentSection
                treatmentSection
                validationSection
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.screenBackground)
            .navigationTitle("新增評價")
            .navigationBarTitleDisplayMode(.inline)
        .confetti(isShowing: $showConfetti)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("提交")
                        }
                    }
                        .fontWeight(.semibold)
                        .disabled(!canSubmit || isSubmitting)
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                    .fontWeight(.semibold)
                }
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

    // MARK: - Sections

    private var ratingSection: some View {
        Section {
            VStack(alignment: .center, spacing: 10) {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            rating = value
                        } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(value <= rating ? AppTheme.warning : .gray.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) 星")
                    }
                }

                Text(ratingDescription)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        } header: {
            Label("整體評分", systemImage: "star.fill")
        }
    }

    private var contentSection: some View {
        Section {
            TextField("例如：醫生很有耐心", text: $title)
                .focused($focusedField, equals: .title)

            TextField("分享你的診療經驗...", text: $content, axis: .vertical)
                .lineLimit(4...8)
                .focused($focusedField, equals: .content)
        } header: {
            Label("評價內容", systemImage: "text.bubble.fill")
        } footer: {
            Text("標題和內容均為必填項目")
        }
    }

    private var treatmentSection: some View {
        Section {
            Picker("治療類型", selection: $treatmentType) {
                ForEach(treatmentTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }

            HStack {
                Text("HKD")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                TextField("實際收費（選填）", text: $cost)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .cost)
            }

            if hasInvalidCost {
                Label("請輸入有效金額，或留空。", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.warning)
            }
        } header: {
            Label("治療與費用", systemImage: "dollarsign.circle.fill")
        } footer: {
            Text(clinicName)
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if let validationMessage {
            Section {
                Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Computed properties

    private var ratingDescription: String {
        switch rating {
        case 1: return "非常不滿意"
        case 2: return "不滿意"
        case 3: return "一般"
        case 4: return "滿意"
        case 5: return "非常滿意"
        default: return ""
        }
    }

    private var canSubmit: Bool {
        !trimmed(title).isEmpty && !trimmed(content).isEmpty && !hasInvalidCost
    }

    private var hasInvalidCost: Bool {
        !trimmed(cost).isEmpty && parsedCost == nil
    }

    private var parsedCost: Decimal? {
        let value = trimmed(cost).replacingOccurrences(of: ",", with: "")
        guard !value.isEmpty else { return nil }
        return Decimal(string: value)
    }

    // MARK: - Submission

    private func submit() async {
        guard !trimmed(title).isEmpty else {
            validationMessage = "請填寫評價標題。"
            return
        }

        guard !trimmed(content).isEmpty else {
            validationMessage = "請填寫評價內容。"
            return
        }

        guard (1...5).contains(rating) else {
            validationMessage = "請選擇評分。"
            return
        }

        guard !hasInvalidCost else {
            validationMessage = "請輸入有效金額，或留空後再提交。"
            return
        }

        let draft = ReviewDraft(
            rating: rating,
            title: title,
            content: content,
            treatmentType: treatmentType,
            cost: parsedCost
        )

        switch submissionContinuation.request(
            draft,
            authentication: authenticationPhase
        ) {
        case .perform(let authenticatedDraft):
            await performSubmission(authenticatedDraft)
        case .waitForAuthentication:
            validationMessage = String(localized: "正在確認登入狀態，草稿已保留。")
        case .presentLogin:
            validationMessage = String(
                localized: "登入或註冊後會自動繼續提交，草稿不會遺失。"
            )
            presentLogin()
        }
    }

    private func performSubmission(_ draft: ReviewDraft) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        let result = await onSubmit(draft)
        isSubmitting = false
        guard !Task.isCancelled else { return }

        switch result {
        case .submitted:
            submissionContinuation.cancel()
            dismiss()
        case .authenticationRequired:
            submissionContinuation.deferUntilAuthenticated(draft)
            validationMessage = String(
                localized: "登入或註冊後會自動繼續提交，草稿不會遺失。"
            )
            presentLogin()
        case .failed(let message):
            submissionContinuation.cancel()
            validationMessage = message
        }
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

    private func authenticationDidChange() {
        guard submissionContinuation.hasPendingAction else { return }
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
            submissionContinuation.cancel()
            validationMessage = String(localized: "草稿已保留；登入後可再次提交。")
            return
        }
        didAuthenticateDuringLogin = false
        resumeAfterLogin()
    }

    private func resumeAfterLogin() {
        guard let draft = submissionContinuation.takeIfAuthenticated(authenticationPhase) else {
            if authenticationPhase == .signedOut {
                submissionContinuation.cancel()
                validationMessage = String(localized: "草稿已保留；登入後可再次提交。")
            }
            return
        }
        Task { await performSubmission(draft) }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

#Preview {
    AddReviewView(clinicName: "VetMap 測試診所") { _ in .submitted }
}
