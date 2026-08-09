//
//  RideBookingAppApp.swift
//  RideBookingApp
//
//  Phase 2 — App entry point. Firebase is now configured on launch.
//

import SwiftUI
import FirebaseCore

@main
struct RideBookingAppApp: App {

    // Central app-wide session/auth state (see Services/SessionManager.swift)
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var router = Router()

    init() {
        FirebaseApp.configure()
        print("✅ RideBookingApp launched — environment: \(AppEnvironment.current)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(router)
        }
    }
}
