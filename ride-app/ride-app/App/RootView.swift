//
//  RootView.swift
//  RideBookingApp
//
//  Phase 2 — Branches between Splash / Auth flow / Home flow based on
//  `sessionManager` state, restoring session automatically on relaunch.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router

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
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
