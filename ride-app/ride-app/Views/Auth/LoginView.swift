//
//  LoginView.swift
//  RideBookingApp
//
//  Phase 2 — Email/password sign-in. On success, commits the returned
//  AppUser into SessionManager which flips RootView over to the Home flow.
//

import SwiftUI

struct LoginView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(spacing: 14) {
                    TextField("Email", text: $viewModel.loginEmail)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $viewModel.loginPassword)
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
                        if let user = await viewModel.signIn() {
                            sessionManager.currentUser = user
                            sessionManager.isLoggedIn = true
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Log In").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(viewModel.isLoading)

                Button("Forgot password?") {
                    router.push(.forgotPassword)
                }
                .font(.footnote)

                Divider().padding(.horizontal)

                Button("Create an account") {
                    router.push(.roleSelection)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 40)
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "car.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Welcome back")
                .font(.title2.bold())
            Text("Log in to continue")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack { LoginView() }
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
