import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Color.surface.ignoresSafeArea()

                VStack(spacing: AppTheme.Space.xl) {
                    VStack(spacing: AppTheme.Space.xs) {
                        Text("Create Account")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Sign up to store your tasks securely.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Color.muted)
                    }
                    .padding(.top, AppTheme.Space.xl)

                    VStack(spacing: AppTheme.Space.md) {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(AppTheme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))

                        SecureField("Password", text: $password)
                            .padding()
                            .background(AppTheme.Color.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))

                        if let msg = authVM.errorMessage {
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Color.destructive)
                        }

                        Button {
                            authVM.register(email: email, password: password)
                        } label: {
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppTheme.Color.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.lg)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
