//
//  RootView.swift
//  RideBookingApp
//
//  Phase 1 — Placeholder root screen.
//  From Phase 2 onward, this will branch between Auth flow and Home flow
//  based on `sessionManager.isLoggedIn`.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    router.destination(for: route)
                }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
