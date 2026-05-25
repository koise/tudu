import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false

    var body: some View {
        ZStack {
            AppTheme.Color.surface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppTheme.Space.xl) {
                    // Wordmark
                    VStack(spacing: AppTheme.Space.xs) {
                        Image(systemName: "checkmark.square.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.Color.accent)

                        Text("Taskly")
                            .font(.system(size: 32, weight: .bold, design: .rounded))

                        Text("Your tasks. Always in sync.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Color.muted)
                    }
                    .padding(.top, AppTheme.Space.xl * 2)

                    // Form card
                    VStack(spacing: AppTheme.Space.md) {
                        AuthTextField(label: "Email", text: $email,
                                      keyboard: .emailAddress, isSecure: false)
                        AuthTextField(label: "Password", text: $password,
                                      keyboard: .default, isSecure: true)

                        if let msg = authVM.errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Color.destructive)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, AppTheme.Space.xs)
                        }

                        PrimaryButton(title: "Sign In", isLoading: authVM.isLoading) {
                            authVM.signIn(email: email, password: password)
                        }
                    }
                    .padding(AppTheme.Space.lg)
                    .background(AppTheme.Color.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
                    .padding(.horizontal, AppTheme.Space.md)

                    // Register link
                    Button {
                        showRegister = true
                    } label: {
                        Text("No account? ")
                            .foregroundStyle(AppTheme.Color.muted)
                        + Text("Create one →")
                            .foregroundStyle(AppTheme.Color.accent)
                    }
                    .font(.subheadline)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showRegister) {
            RegisterView()
        }
    }
}

// MARK: - Sub-components

private struct AuthTextField: View {
    let label: String
    @Binding var text: String
    let keyboard: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.xs) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(AppTheme.Color.muted)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            .padding(.horizontal, AppTheme.Space.md)
            .padding(.vertical, AppTheme.Space.sm + 2)
            .background(AppTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
        }
    }
}

private struct PrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.md)
        }
        .background(AppTheme.Color.accent)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
        .disabled(isLoading)
    }
}
