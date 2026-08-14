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
//  UPDATED — Firebase resolves `isLoadingAuthState` almost instantly
//  (especially with a cached session), which made the splash screen flash
//  by before its entrance animation could play. `minimumSplashElapsed`
//  enforces a floor on how long the splash stays up, independent of how
//  fast auth actually resolves — the splash now shows until BOTH auth has
//  resolved AND the minimum time has passed, whichever is later.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router
    @EnvironmentObject var pushService: PushNotificationService

    @State private var minimumSplashElapsed = false
    private let minimumSplashDuration: Duration = .seconds(2.00)   // 👈 change this number

    private var showSplash: Bool {
        sessionManager.isLoadingAuthState || !minimumSplashElapsed
    }

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .task {
                        try? await Task.sleep(for: minimumSplashDuration)
                        minimumSplashElapsed = true
                    }
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
        .animation(.default, value: minimumSplashElapsed)
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
