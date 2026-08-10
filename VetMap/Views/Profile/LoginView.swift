import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isShowingPasswordReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    brandingHeader

                    VStack(spacing: 16) {
                        emailField
                        passwordField
                        forgotPasswordButton
                    }
                    .padding(.horizontal, 16)

                    errorSection

                    signInButton

                    appleSignInButton

                    Spacer()

                    signUpLink
                }
                .padding(.vertical, 32)
            }
            .background(AppTheme.screenBackground)
            .onAppear {
                authViewModel.clearError()
            }
            .sheet(isPresented: $isShowingPasswordReset) {
                PasswordResetView(
                    authViewModel: authViewModel,
                    initialEmail: email
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("關閉")
                }
            }
        }
    }

    // MARK: - Branding

    private var brandingHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primary)

            Text("VetMap")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(AppTheme.primary)

            Text("願世間再無誤診毛孩")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Fields

    private var emailField: some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField("電子郵件", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .accessibilityLabel("電子郵件")
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    private var passwordField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            SecureField("密碼", text: $password)
                .textContentType(.password)
                .accessibilityLabel("密碼")
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    private var forgotPasswordButton: some View {
        Button("忘記密碼？") {
            isShowingPasswordReset = true
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
        .contentShape(Rectangle())
        .disabled(isLoading || authViewModel.isAuthenticating)
        .accessibilityIdentifier("login.forgotPassword")
        .accessibilityHint("開啟重設密碼頁面")
    }

    // MARK: - Error

    @ViewBuilder
    private var errorSection: some View {
        if let error = authViewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Buttons

    private var signInButton: some View {
        Button {
            Task {
                isLoading = true
                await authViewModel.signIn(email: email, password: password)
                isLoading = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text("登入")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .disabled(
            isLoading
                || authViewModel.isAuthenticating
                || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || password.isEmpty
        )
        .padding(.horizontal, 16)
        .accessibilityLabel("登入")
        .accessibilityHint("使用電子郵件和密碼登入")
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            authViewModel.prepareAppleRequest(request, purpose: .signIn)
        } onCompletion: { result in
            authViewModel.processAppleAuthorization(result: result, purpose: .signIn)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
        .disabled(isLoading || authViewModel.isAuthenticating)
        .accessibilityLabel("使用 Apple 登入")
    }

    // MARK: - Navigation

    private var signUpLink: some View {
        NavigationLink {
            SignUpView(authViewModel: authViewModel)
        } label: {
            HStack(spacing: 4) {
                Text("還沒有帳號？")
                    .foregroundStyle(.secondary)
                Text("註冊")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
            }
            .font(.subheadline)
        }
        .accessibilityLabel("註冊新帳戶")
    }
}

private struct PasswordResetView: View {
    private enum AccessibilityTarget: Hashable {
        case fieldError
        case requestError
        case success
    }

    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var accessibilityFocus: AccessibilityTarget?

    @State private var email: String
    @State private var fieldError: String?
    @State private var requestError: String?
    @State private var isSending = false
    @State private var isAccepted = false

    init(authViewModel: AuthViewModel, initialEmail: String) {
        self.authViewModel = authViewModel
        _email = State(initialValue: initialEmail)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("輸入你的帳戶電子郵件，我們會傳送重設密碼連結。")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    emailSection

                    if isAccepted {
                        successMessage
                    } else {
                        requestErrorMessage
                        sendButton
                    }
                }
                .padding(20)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("重設密碼")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSending)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isAccepted ? "完成" : "取消") {
                        dismiss()
                    }
                    .disabled(isSending)
                    .accessibilityIdentifier("passwordReset.dismiss")
                }
            }
        }
    }

    private var emailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("電子郵件", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(
                    Color(.systemBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(fieldError == nil ? AppTheme.hairline : Color.red, lineWidth: 1)
                }
                .disabled(isSending || isAccepted)
                .accessibilityIdentifier("passwordReset.email")
                .onChange(of: email) {
                    fieldError = nil
                    requestError = nil
                }

            if let fieldError {
                Label(fieldError, systemImage: "exclamationmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("passwordReset.emailError")
                    .accessibilityFocused($accessibilityFocus, equals: .fieldError)
            }
        }
    }

    private var successMessage: some View {
        Label {
            Text("如果此電子郵件已註冊，你稍後會收到重設密碼電郵。請檢查收件箱及垃圾郵件。")
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .font(.callout)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("passwordReset.success")
        .accessibilityFocused($accessibilityFocus, equals: .success)
    }

    @ViewBuilder
    private var requestErrorMessage: some View {
        if let requestError {
            Label(requestError, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("passwordReset.requestError")
                .accessibilityFocused($accessibilityFocus, equals: .requestError)
        }
    }

    private var sendButton: some View {
        Button {
            sendResetEmail()
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView()
                        .tint(.white)
                }
                Text(isSending ? "正在傳送重設密碼電郵" : "傳送重設密碼電郵")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .foregroundStyle(.white)
        .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .disabled(isSending)
        .accessibilityIdentifier("passwordReset.send")
        .accessibilityLabel(isSending ? "正在傳送重設密碼電郵" : "傳送重設密碼電郵")
    }

    private func sendResetEmail() {
        guard !isSending else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            fieldError = String(localized: "請輸入電子郵件。")
            accessibilityFocus = .fieldError
            return
        }

        isSending = true
        fieldError = nil
        requestError = nil

        Task {
            let outcome = await authViewModel.sendPasswordReset(email: trimmedEmail)
            isSending = false

            switch outcome {
            case .accepted:
                isAccepted = true
                accessibilityFocus = .success
            case .invalidEmail:
                fieldError = String(localized: "電子郵件格式不正確。")
                accessibilityFocus = .fieldError
            case .failed(let message):
                requestError = message
                accessibilityFocus = .requestError
            }
        }
    }
}

#Preview {
    LoginView(authViewModel: .shared)
}
