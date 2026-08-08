//
//  Router.swift
//  RideBookingApp
//
//  Phase 1 — Lightweight Router/Coordinator built on NavigationStack.
//  Add new cases to `AppRoute` as new screens are built in later phases.
//

import SwiftUI

enum AppRoute: Hashable {
    case login
    case signUp
    case roleSelection
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

    /// Maps a route to its destination view.
    /// Views referenced here are stubbed as later phases build them out —
    /// for now only Home exists (Phase 1), so this switch will grow phase by phase.
    @ViewBuilder
    func destination(for route: AppRoute) -> some View {
        switch route {
        case .login:
            Text("Login — build in Phase 2")
        case .signUp:
            Text("Sign Up — build in Phase 2")
        case .roleSelection:
            Text("Role Selection — build in Phase 2")
        case .profile:
            Text("Profile — build in Phase 3")
        case .editProfile:
            Text("Edit Profile — build in Phase 3")
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
