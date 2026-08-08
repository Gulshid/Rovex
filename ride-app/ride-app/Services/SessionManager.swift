//
//  SessionManager.swift
//  RideBookingApp
//
//  Phase 1 — Central ObservableObject holding app-wide session state.
//  Phase 2 wires this to FirebaseAuth's addStateDidChangeListener so
//  `currentUser` / `isLoggedIn` update automatically on sign-in/out.
//

import Foundation
import Combine

/// Minimal placeholder — replaced by the full Codable `User` model in Phase 4.
struct AppUser: Identifiable, Equatable {
    let id: String
    var name: String
    var email: String
    var role: UserRole
}

enum UserRole: String, Codable {
    case rider
    case driver
}

@MainActor
final class SessionManager: ObservableObject {

    @Published var currentUser: AppUser?
    @Published var isLoggedIn: Bool = false
    @Published var isLoadingAuthState: Bool = true

    init() {
        // Phase 2 TODO:
        // Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
        //     Task { @MainActor in
        //         self?.handle(firebaseUser)
        //     }
        // }
        isLoadingAuthState = false
    }

    func signOut() {
        // Phase 2 TODO: try? Auth.auth().signOut()
        currentUser = nil
        isLoggedIn = false
    }
}
