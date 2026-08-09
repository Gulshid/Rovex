//
//  SessionManager.swift
//  RideBookingApp
//
//  Phase 2 — Central ObservableObject holding app-wide session state.
//  Wired to FirebaseAuth's addStateDidChangeListener so `currentUser` /
//  `isLoggedIn` update automatically on sign-in/out, restoring session
//  across app restarts.
//
//  Note: the AppUser / UserRole / VehicleDetails models now live in
//  Models/User.swift (Phase 4 groundwork) instead of being defined here.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class SessionManager: ObservableObject {

    @Published var currentUser: AppUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoadingAuthState: Bool = true

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                await self?.handle(firebaseUser)
            }
        }
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    private func handle(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            currentUser = nil
            isLoggedIn = false
            isLoadingAuthState = false
            return
        }

        do {
            let user = try await UserService.shared.fetchUser(uid: firebaseUser.uid)
            currentUser = user
            isLoggedIn = true
        } catch {
            // Firestore doc not yet created, or offline — treat as logged out
            // rather than crash; user can retry sign-in.
            currentUser = nil
            isLoggedIn = false
        }
        isLoadingAuthState = false
    }

    /// Re-fetches the current user's Firestore doc — call after profile edits.
    func refreshCurrentUser() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if let user = try? await UserService.shared.fetchUser(uid: uid) {
            currentUser = user
        }
    }

    func signOut() {
        try? AuthService.shared.signOut()
        currentUser = nil
        isLoggedIn = false
    }
}
