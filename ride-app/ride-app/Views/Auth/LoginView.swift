//
//  LoginView.swift
//  RideBookingApp
//
//  Phase 2 — Email/password sign-in. On success, commits the returned
//  AppUser into SessionManager which flips RootView over to the Home flow.
//
//  UPDATED — Polished visual pass: branded header, custom field styling
//  with icons/focus states, show/hide password, inline validation cues,
//  and haptic + animated feedback on error. Behavior/wiring unchanged.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router
    @StateObject private var viewModel = AuthViewModel()

    private enum Field: Hashable {
        case email, password
    }

    @FocusState private var focusedField: Field?
    @State private var isPasswordVisible = false
    @State private var didShakeOnError = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                header

                VStack(spacing: Theme.Spacing.md) {
                    AuthTextField(
                        title: "Email",
                        text: $viewModel.loginEmail,
                        icon: "envelope",
                        keyboardType: .emailAddress,
                        textContentType: .username
                    )
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                    AuthSecureField(
                        title: "Password",
                        text: $viewModel.loginPassword,
                        isVisible: $isPasswordVisible,
                        textContentType: .password
                    )
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { attemptSignIn() }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                if let error = viewModel.errorMessage {
                    ErrorBanner(message: error)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        attemptSignIn()
                    } label: {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(viewModel.isLoading || !canSubmit)
                    .opacity(canSubmit ? 1 : 0.6)
                    .animation(.easeInOut(duration: 0.15), value: canSubmit)

                    Button("Forgot password?") {
                        router.push(.forgotPassword)
                    }
                    .font(.footnote.weight(.medium))
                }
                .padding(.horizontal, Theme.Spacing.lg)

                dividerWithLabel

                Button {
                    router.push(.roleSelection)
                } label: {
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .foregroundStyle(.secondary)
                        Text("Sign up")
                            .fontWeight(.semibold)
                            .foregroundStyle(.tint)
                    }
                    .font(.subheadline)
                }
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.vertical, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationBarHidden(true)
        .onChange(of: viewModel.errorMessage) { newValue in
            guard newValue != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(Theme.AnimationToken.statusChange) { didShakeOnError.toggle() }
        }
        .animation(Theme.AnimationToken.statusChange, value: viewModel.errorMessage)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 12, y: 6)

                Image(systemName: "car.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, Theme.Spacing.xs)

            Text("Welcome back")
                .font(.title2.bold())
            Text("Log in to continue with Rovex")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var dividerWithLabel: some View {
        HStack {
            VStack { Divider() }
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack { Divider() }
        }
        .padding(.horizontal, Theme.Spacing.lg)
    }

    // MARK: - Logic

    private var canSubmit: Bool {
        !viewModel.loginEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !viewModel.loginPassword.isEmpty
    }

    private func attemptSignIn() {
        focusedField = nil
        guard canSubmit else { return }
        Task {
            if let user = await viewModel.signIn() {
                sessionManager.currentUser = user
                sessionManager.isLoggedIn = true
            }
        }
    }
}

// MARK: - Shared field components (used by both Login and Sign Up)

/// A plain text field with a leading icon and a focus-aware border, matching
/// the rounded-card visual language used elsewhere in the app (see Theme).
struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var icon: String
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                .frame(width: 20)

            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .focused($isFocused)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 50)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// A secure field with a leading lock icon, a focus-aware border, and a
/// show/hide toggle so users can verify what they've typed before submitting.
struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    var textContentType: UITextContentType? = nil

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "lock")
                .foregroundStyle(isFocused ? Color.accentColor : .secondary)
                .frame(width: 20)

            Group {
                if isVisible {
                    TextField(title, text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField(title, text: $text)
                }
            }
            .textContentType(textContentType)
            .focused($isFocused)

            Button {
                isVisible.toggle()
            } label: {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isVisible ? "Hide password" : "Show password")
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: 50)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .stroke(isFocused ? Color.accentColor : .clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Compact inline error banner used across Auth screens.
struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.red)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.sm)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.chip))
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
