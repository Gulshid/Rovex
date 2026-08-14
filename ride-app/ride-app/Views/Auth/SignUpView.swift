import SwiftUI

struct SignUpView: View {

    let role: UserRole

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = AuthViewModel()

    private enum Field: Hashable {
        case name, email, password, confirmPassword
    }

    @FocusState private var focusedField: Field?

    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header

                VStack(spacing: Theme.Spacing.md) {
                    AuthTextField(
                        title: "Full name",
                        text: $viewModel.name,
                        icon: "person",
                        textContentType: .name
                    )
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .textInputAutocapitalization(.words)

                    AuthTextField(
                        title: "Email",
                        text: $viewModel.email,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        textContentType: .emailAddress
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        AuthSecureField(
                            title: "Password",
                            text: $viewModel.password,
                            isVisible: $isPasswordVisible,
                            textContentType: .newPassword
                        )
                        .focused($focusedField, equals: .password)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirmPassword }

                        if !viewModel.password.isEmpty {
                            PasswordStrengthMeter(password: viewModel.password)
                                .transition(.opacity)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        AuthSecureField(
                            title: "Confirm password",
                            text: $viewModel.confirmPassword,
                            isVisible: $isConfirmPasswordVisible,
                            textContentType: .newPassword
                        )
                        .focused($focusedField, equals: .confirmPassword)
                        .submitLabel(.done)
                        .onSubmit { attemptSignUp() }

                        if !viewModel.confirmPassword.isEmpty {
                            passwordMatchLabel
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .animation(.easeInOut(duration: 0.15), value: viewModel.password)
                .animation(.easeInOut(duration: 0.15), value: viewModel.confirmPassword)

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Text("By creating an account, you agree to Rovex's Terms of Service and Privacy Policy.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)

                Button {
                    attemptSignUp()
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Create Account")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                .padding(.horizontal, Theme.Spacing.lg)
                .disabled(viewModel.isLoading)
            }
            .padding(.vertical, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.selectedRole = role }
        .onChange(of: viewModel.errorMessage) { newValue in
            guard newValue != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        .animation(Theme.AnimationToken.statusChange, value: viewModel.errorMessage)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: role == .driver ? "car.fill" : "person.fill")
                Text(role == .driver ? "Driver account" : "Rider account")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(Color.accentColor, in: Capsule())

            Text("Create your \(role == .driver ? "Driver" : "Rider") account")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("It only takes a minute to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var passwordMatchLabel: some View {
        let matches = viewModel.password == viewModel.confirmPassword
        return HStack(spacing: 4) {
            Image(systemName: matches ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(matches ? "Passwords match" : "Passwords don't match")
        }
        .font(.caption)
        .foregroundStyle(matches ? .green : .red)
        .padding(.leading, Theme.Spacing.xs)
    }

    // MARK: - Logic

    private func attemptSignUp() {
        focusedField = nil
        Task {
            if let user = await viewModel.signUp() {
                sessionManager.currentUser = user
                sessionManager.isLoggedIn = true
            }
        }
    }
}

// MARK: - Password strength meter

/// Lightweight heuristic strength meter (length + character variety). This
/// is purely a UX affordance — AuthViewModel.signUpValidationError remains
/// the source of truth for what's actually required to submit.
struct PasswordStrengthMeter: View {
    let password: String

    private enum Strength: Int, CaseIterable {
        case weak = 1, fair = 2, good = 3, strong = 4

        var label: String {
            switch self {
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .good: return "Good"
            case .strong: return "Strong"
            }
        }

        var color: Color {
            switch self {
            case .weak: return .red
            case .fair: return .orange
            case .good: return .yellow
            case .strong: return .green
            }
        }
    }

    private var strength: Strength {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil
            || password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*_-+=?")) != nil {
            score += 1
        }
        return Strength(rawValue: max(1, min(score, 4))) ?? .weak
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Strength.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level.rawValue <= strength.rawValue ? strength.color : Color(.systemGray5))
                        .frame(height: 4)
                }
            }
            Text(strength.label)
                .font(.caption2)
                .foregroundStyle(strength.color)
        }
        .padding(.leading, Theme.Spacing.xs)
    }
}

#Preview {
    NavigationStack { SignUpView(role: .rider) }
        .environmentObject(SessionManager())
}
