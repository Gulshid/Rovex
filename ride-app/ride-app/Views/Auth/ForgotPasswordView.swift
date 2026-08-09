//
//  ForgotPasswordView.swift
//  RideBookingApp
//
//  Phase 2 — Sends a Firebase Auth password reset email.
//

import SwiftUI

struct ForgotPasswordView: View {

    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Reset your password")
                .font(.title2.bold())
            Text("Enter your email and we'll send you a reset link.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Email", text: $viewModel.resetEmail)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            if let error = viewModel.errorMessage {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let info = viewModel.infoMessage {
                Text(info).font(.footnote).foregroundStyle(.green)
            }

            Button {
                Task {
                    if await viewModel.sendPasswordReset() {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        dismiss()
                    }
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Send Reset Link").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Spacer()
        }
        .padding()
        .navigationTitle("Forgot Password")
    }
}

#Preview {
    NavigationStack { ForgotPasswordView() }
}
