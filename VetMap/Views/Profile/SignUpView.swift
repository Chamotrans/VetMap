import SwiftUI

struct SignUpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var validationError: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                brandingHeader

                VStack(spacing: 16) {
                    displayNameField
                    emailField
                    passwordField
                    confirmPasswordField
                }
                .padding(.horizontal, 16)

                validationErrorSection
                authErrorSection

                signUpButton

                Spacer()

                loginLink
            }
            .padding(.vertical, 32)
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("註冊")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Branding

    private var brandingHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.primary)

            Text("建立帳號")
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text("加入 VetMap，守護毛孩健康")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Fields

    private var displayNameField: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            TextField("顯示名稱", text: $displayName)
                .autocapitalization(.words)
                .accessibilityLabel("顯示名稱")
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

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
            SecureField("密碼（至少6個字元）", text: $password)
                .textContentType(.newPassword)
                .accessibilityLabel("密碼")
                .accessibilityHint("至少六個字元")
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    private var confirmPasswordField: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.rectangle.fill")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            SecureField("確認密碼", text: $confirmPassword)
                .textContentType(.newPassword)
                .accessibilityLabel("確認密碼")
        }
        .padding(14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
    }

    // MARK: - Errors

    @ViewBuilder
    private var validationErrorSection: some View {
        if let error = validationError {
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

    @ViewBuilder
    private var authErrorSection: some View {
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

    // MARK: - Button

    private var signUpButton: some View {
        Button {
            guard validate() else { return }
            Task {
                isLoading = true
                await authViewModel.signUp(email: email, password: password, displayName: displayName)
                isLoading = false
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
                Text("註冊")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .background(AppTheme.primary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .disabled(isLoading)
        .padding(.horizontal, 16)
        .accessibilityLabel("註冊")
        .accessibilityHint("建立新帳戶")
    }

    // MARK: - Navigation

    private var loginLink: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Text("已有帳號？")
                    .foregroundStyle(.secondary)
                Text("登入")
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.primary)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Validation

    private func validate() -> Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty,
              !trimmedEmail.isEmpty,
              !trimmedPassword.isEmpty,
              !confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "請填寫所有欄位。"
            return false
        }

        guard trimmedPassword.count >= 6 else {
            validationError = "密碼長度至少需要6個字元。"
            return false
        }

        guard password == confirmPassword else {
            validationError = "兩次輸入的密碼不一致。"
            return false
        }

        validationError = nil
        return true
    }
}

#Preview {
    NavigationStack {
        SignUpView(authViewModel: AuthViewModel())
    }
}
