//
//  RootView.swift
//  RideBookingApp
//
//  Phase 2 — Branches between Splash / Auth flow / Home flow based on
//  `sessionManager` state, restoring session automatically on relaunch.
//
//  UPDATED in Phase 11 — observes PushNotificationService.pendingDeepLink
//  so tapping a ride-status notification (local or remote) pushes the
//  right screen: riders land on RideTrackingView, drivers on
//  ActiveDriverRideView. Only acted on once logged in and once there's a
//  real NavigationStack to push onto.
//
//  FIX — clears router.path whenever isLoggedIn changes, in EITHER
//  direction. Both branches below bind to the same $router.path, so a
//  stale path carries straight over when the root view swaps:
//   - false: e.g. Profile screen still in path is not carried over into
//     the logged-out NavigationStack, which caused the Profile screen to
//     appear with a spinner instead of returning to LoginView.
//   - true: e.g. RoleSelectionView/SignUpView still in path after sign
//     up, which caused HomeView to become the root underneath while the
//     user kept looking at SignUpView until they tapped back.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router
    @EnvironmentObject var pushService: PushNotificationService

    var body: some View {
        Group {
            if sessionManager.isLoadingAuthState {
                SplashView()
            } else if sessionManager.isLoggedIn {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: AppRoute.self) { route in
                            router.destination(for: route)
                        }
                }
                .onAppear {
                    // Ask for notification permission + register for FCM
                    // once we know who's signed in.
                    PushNotificationService.shared.requestAuthorizationIfNeeded()
                    PushNotificationService.shared.syncTokenToCurrentUser()
                }
            } else {
                NavigationStack(path: $router.path) {
                    LoginView()
                        .navigationDestination(for: AppRoute.self) { route in
                            router.destination(for: route)
                        }
                }
            }
        }
        .animation(.default, value: sessionManager.isLoggedIn)
        .onChange(of: sessionManager.isLoggedIn) { _, _ in
            router.popToRoot()
        }
        .onChange(of: pushService.pendingDeepLink) { _, deepLink in
            guard let deepLink, sessionManager.isLoggedIn else { return }
            switch deepLink.kind {
            case .rideTracking:
                router.push(.rideTracking(rideId: deepLink.rideId))
            case .activeDriverRide:
                router.push(.activeDriverRide(rideId: deepLink.rideId))
            }
            pushService.pendingDeepLink = nil
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
        .environmentObject(Router())
        .environmentObject(PushNotificationService.shared)
}
