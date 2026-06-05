import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    brandingHeader

                    VStack(spacing: 16) {
                        emailField
                        passwordField
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
            .navigationBarHidden(true)
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
        .disabled(isLoading)
        .padding(.horizontal, 16)
        .accessibilityLabel("登入")
        .accessibilityHint("使用電子郵件和密碼登入")
    }

    private var appleSignInButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            authViewModel.processAppleSignIn(result: result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 16)
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

#Preview {
    LoginView(authViewModel: AuthViewModel())
}
