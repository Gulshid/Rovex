//
//  AuthViewModel.swift
//  RideBookingApp
//
//  Phase 2 — Form state, validation, and loading/error state for the
//  Login / Sign Up / Forgot Password screens. Views own the moment of
//  committing a returned AppUser into SessionManager (keeps this class
//  independent of environment-injection timing).
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    // Sign up fields
    @Published var name = ""
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var selectedRole: UserRole = .rider

    // Sign in fields
    @Published var loginEmail = ""
    @Published var loginPassword = ""

    // Forgot password
    @Published var resetEmail = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    var signUpValidationError: String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty { return "Please enter your name." }
        if !email.contains("@") || !email.contains(".") { return "Please enter a valid email." }
        if password.count < 6 { return "Password must be at least 6 characters." }
        if password != confirmPassword { return "Passwords don't match." }
        return nil
    }

    /// Returns the created AppUser on success, or nil (with errorMessage set) on failure.
    func signUp() async -> AppUser? {
        errorMessage = nil
        if let validationError = signUpValidationError {
            errorMessage = validationError
            return nil
        }
        isLoading = true
        defer { isLoading = false }
        do {
            return try await AuthService.shared.signUp(
                name: name.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password,
                role: selectedRole
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Returns the signed-in AppUser on success, or nil (with errorMessage set) on failure.
    func signIn() async -> AppUser? {
        errorMessage = nil
        guard !loginEmail.isEmpty, !loginPassword.isEmpty else {
            errorMessage = "Please enter your email and password."
            return nil
        }
        isLoading = true
        defer { isLoading = false }
        do {
            return try await AuthService.shared.signIn(
                email: loginEmail.trimmingCharacters(in: .whitespaces).lowercased(),
                password: loginPassword
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Returns true on success (email sent).
    func sendPasswordReset() async -> Bool {
        errorMessage = nil
        infoMessage = nil
        guard !resetEmail.isEmpty else {
            errorMessage = "Please enter your email."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await AuthService.shared.resetPassword(
                email: resetEmail.trimmingCharacters(in: .whitespaces).lowercased()
            )
            infoMessage = "Password reset email sent. Check your inbox."
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
