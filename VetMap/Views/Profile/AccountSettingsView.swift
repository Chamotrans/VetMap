import AuthenticationServices
import SwiftUI

struct AccountSettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showDeleteAccount = false

    var body: some View {
        Form {
            Section("帳戶") {
                LabeledContent("顯示名稱") {
                    Text(authViewModel.user?.displayName ?? "VetMap 用戶")
                }

                if let email = authViewModel.user?.email, !email.isEmpty {
                    LabeledContent("電子郵件") {
                        Text(email)
                            .multilineTextAlignment(.trailing)
                    }
                }

                LabeledContent("登入方式") {
                    Text(authViewModel.accountProvider.displayName)
                }
            }

            Section {
                Button(role: .destructive) {
                    authViewModel.clearError()
                    showDeleteAccount = true
                } label: {
                    Label("刪除帳戶", systemImage: "person.crop.circle.badge.minus")
                }
                .accessibilityHint("永久刪除 VetMap 帳戶及相關資料")
            } header: {
                Text("帳戶管理")
            } footer: {
                Text("你可以直接在 App 內提出刪除帳戶。完成安全驗證後，帳戶及相關投稿資料將會永久刪除。")
            }
        }
        .navigationTitle("帳號設定")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(authViewModel: authViewModel)
                .interactiveDismissDisabled(authViewModel.isDeletingAccount)
        }
        .onChange(of: authViewModel.authState) { _, state in
            if state == .signedOut {
                showDeleteAccount = false
            }
        }
    }
}

private struct DeleteAccountView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var confirmationText = ""
    @State private var password = ""

    private var hasConfirmedDeletion: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines) == "刪除"
    }

    var body: some View {
        NavigationStack {
            Form {
                warningSection
                confirmationSection
                authenticationSection
                errorSection
            }
            .navigationTitle("永久刪除帳戶")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(authViewModel.isDeletingAccount)
                }
            }
            .onAppear {
                authViewModel.clearError()
            }
            .onChange(of: authViewModel.authState) { _, state in
                if state == .signedOut {
                    dismiss()
                }
            }
        }
    }

    private var warningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("這項操作無法復原")
                        .font(.headline)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }

                Text(
                    "系統會永久刪除你的 VetMap 帳戶、個人資料，以及由你提交的診所、評價、報價和舉報資料。"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var confirmationSection: some View {
        Section {
            TextField("輸入「刪除」", text: $confirmationText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .accessibilityLabel("輸入刪除以確認")
        } header: {
            Text("確認")
        } footer: {
            Text("請輸入「刪除」，再完成登入驗證。")
        }
    }

    @ViewBuilder
    private var authenticationSection: some View {
        switch authViewModel.accountProvider {
        case .email:
            Section("使用目前密碼驗證") {
                SecureField("目前密碼", text: $password)
                    .textContentType(.password)

                Button(role: .destructive) {
                    Task {
                        let deleted = await authViewModel.deleteEmailAccount(password: password)
                        if deleted {
                            password = ""
                            dismiss()
                        }
                    }
                } label: {
                    destructiveButtonLabel("驗證並永久刪除")
                }
                .disabled(
                    !hasConfirmedDeletion
                        || password.isEmpty
                        || authViewModel.isDeletingAccount
                )
            }

        case .apple:
            Section {
                Text("Apple 要求在刪除前重新驗證並撤銷登入授權。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SignInWithAppleButton(.continue) { request in
                    authViewModel.prepareAppleRequest(request, purpose: .deleteAccount)
                } onCompletion: { result in
                    authViewModel.processAppleAuthorization(
                        result: result,
                        purpose: .deleteAccount
                    )
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .disabled(!hasConfirmedDeletion || authViewModel.isDeletingAccount)
                .accessibilityLabel("使用 Apple 驗證並永久刪除帳戶")

                if authViewModel.isDeletingAccount {
                    HStack {
                        ProgressView()
                        Text("正在刪除帳戶及相關資料…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("使用 Apple 驗證")
            }

        case .unknown:
            Section {
                ContentUnavailableView(
                    "未能確認登入方式",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("請先登出並重新登入，然後再提出刪除帳戶。")
                )
            }
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = authViewModel.errorMessage {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private func destructiveButtonLabel(_ title: String) -> some View {
        HStack {
            Spacer()
            if authViewModel.isDeletingAccount {
                ProgressView()
                    .tint(.red)
            }
            Text(title)
                .fontWeight(.semibold)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        AccountSettingsView(authViewModel: .shared)
    }
}
