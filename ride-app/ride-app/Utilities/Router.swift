//
//  Router.swift
//  RideBookingApp
//
//  Phase 1 — Lightweight Router/Coordinator built on NavigationStack.
//  Phase 2/3 — Added Auth and Profile routes and wired them to real views.
//

import SwiftUI

enum AppRoute: Hashable {
    case login
    case forgotPassword
    case roleSelection
    case signUp(role: UserRole)
    case profile
    case editProfile
    case bookRide
    case rideTracking(rideId: String)
    case rideHistory
    case rideDetail(rideId: String)
    // Add more as later phases introduce new screens
}

@MainActor
final class Router: ObservableObject {
    @Published var path = NavigationPath()

    func push(_ route: AppRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    /// Maps a route to its destination view. Grows phase by phase.
    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .login:
            LoginView()
        case .forgotPassword:
            ForgotPasswordView()
        case .roleSelection:
            RoleSelectionView()
        case .signUp(let role):
            SignUpView(role: role)
        case .profile:
            ProfileView()
        case .editProfile:
            EditProfileView()
        case .bookRide:
            Text("Book Ride — build in Phase 7")
        case .rideTracking(let rideId):
            Text("Tracking ride \(rideId) — build in Phase 9")
        case .rideHistory:
            Text("Ride History — build in Phase 12")
        case .rideDetail(let rideId):
            Text("Ride Detail \(rideId) — build in Phase 12")
        }
    }
}
