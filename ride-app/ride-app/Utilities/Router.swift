//
//  Router.swift
//  RideBookingApp
//
//  Phase 1 — Lightweight Router/Coordinator built on NavigationStack.
//  Phase 2/3 — Added Auth and Profile routes and wired them to real views.
//  Phase 6 — Added `.mapBooking` (the live map / pickup & drop-off screen).
//  Phase 7 — `.bookRide` now carries the route details chosen on the map
//  screen (pickup/drop-off address + coordinate + distance/ETA) and is
//  wired to the real BookRideView instead of a placeholder.
//  Phase 8 — Added `.driverHome` and `.activeDriverRide(rideId:)` for the
//  Driver-side flow (go online → incoming request → active ride).
//  Phase 9 — `.rideTracking` is now wired to a real live-tracking view
//  instead of a placeholder Text.
//
//  UPDATED in Phase 12 — `.rideHistory`/`.rideDetail` are now wired to
//  real views instead of placeholder Text (they'd been sitting unused
//  since Phase 7). Added `.rateRide(rideId:ratedUserId:isDriver:)` for
//  the post-ride rating screen.
//
//  UPDATED in Phase 13 — added `.chat(rideId:)` for the in-ride chat
//  screen, reachable from both the rider's and driver's active-ride views.
//

import SwiftUI
import CoreLocation

/// CLLocationCoordinate2D isn't Hashable, so routes carry this tiny
/// Hashable/Codable wrapper instead and convert back at the view boundary.
struct RouteCoordinate: Hashable {
    let latitude: Double
    let longitude: Double

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum AppRoute: Hashable {
    case login
    case forgotPassword
    case roleSelection
    case signUp(role: UserRole)
    case profile
    case editProfile
    case mapBooking
    case bookRide(
        pickupAddress: String,
        pickupCoordinate: RouteCoordinate?,
        dropoffAddress: String,
        dropoffCoordinate: RouteCoordinate?,
        distanceKm: Double?,
        durationMin: Double?
    )
    case rideTracking(rideId: String)
    case rideHistory
    case rideDetail(rideId: String)
    case driverHome                              // Phase 8
    case activeDriverRide(rideId: String)        // Phase 8/9
    case rateRide(rideId: String, ratedUserId: String, isDriver: Bool)  // Phase 12
    case chat(rideId: String)                    // Phase 13
    // Add more as later phases introduce new screens
}

extension AppRoute {
    /// Call-site convenience so MapBookingView can keep passing plain
    /// CLLocationCoordinate2D? values instead of wrapping them in
    /// RouteCoordinate itself. Deliberately named differently from the
    /// `.bookRide` case to avoid any ambiguity between an enum case and a
    /// same-named static function.
    static func toBookRide(
        pickupAddress: String,
        pickupCoordinate: CLLocationCoordinate2D?,
        dropoffAddress: String,
        dropoffCoordinate: CLLocationCoordinate2D?,
        distanceKm: Double?,
        durationMin: Double?
    ) -> AppRoute {
        .bookRide(
            pickupAddress: pickupAddress,
            pickupCoordinate: pickupCoordinate.map(RouteCoordinate.init),
            dropoffAddress: dropoffAddress,
            dropoffCoordinate: dropoffCoordinate.map(RouteCoordinate.init),
            distanceKm: distanceKm,
            durationMin: durationMin
        )
    }
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
        case .mapBooking:
            MapBookingView()
        case .bookRide(let pickupAddress, let pickupCoordinate, let dropoffAddress, let dropoffCoordinate, let distanceKm, let durationMin):
            BookRideView(
                pickupAddress: pickupAddress,
                pickupCoordinate: pickupCoordinate?.coordinate,
                dropoffAddress: dropoffAddress,
                dropoffCoordinate: dropoffCoordinate?.coordinate,
                distanceKm: distanceKm,
                durationMin: durationMin
            )
        case .rideTracking(let rideId):
            RideTrackingView(rideId: rideId)
        case .rideHistory:
            RideHistoryView()
        case .rideDetail(let rideId):
            RideDetailView(rideId: rideId)
        case .driverHome:
            DriverHomeView()
        case .activeDriverRide(let rideId):
            ActiveDriverRideView(rideId: rideId)
        case .rateRide(let rideId, let ratedUserId, let isDriver):
            RateRideView(rideId: rideId, ratedUserId: ratedUserId, isDriver: isDriver)
        case .chat(let rideId):
            ChatView(rideId: rideId)
        }
    }
}
