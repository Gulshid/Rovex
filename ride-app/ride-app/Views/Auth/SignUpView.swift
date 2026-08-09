//
//  SignUpView.swift
//  RideBookingApp
//
//  Phase 2 — Creates the Firebase Auth account + Firestore user document
//  for the role chosen in RoleSelectionView.
//

import SwiftUI

struct SignUpView: View {

    let role: UserRole

    @EnvironmentObject var sessionManager: SessionManager
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Create your \(role == .driver ? "Driver" : "Rider") account")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 14) {
                    TextField("Full name", text: $viewModel.name)
                        .textFieldStyle(.roundedBorder)

                    TextField("Email", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Confirm password", text: $viewModel.confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        if let user = await viewModel.signUp() {
                            sessionManager.currentUser = user
                            sessionManager.isLoggedIn = true
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Create Account").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(viewModel.isLoading)
            }
            .padding(.vertical, 32)
        }
        .navigationTitle("Sign Up")
        .onAppear { viewModel.selectedRole = role }
    }
}

#Preview {
    NavigationStack { SignUpView(role: .rider) }
        .environmentObject(SessionManager())
}
