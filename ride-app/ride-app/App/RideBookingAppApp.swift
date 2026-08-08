//
//  RideBookingAppApp.swift
//  RideBookingApp
//
//  Phase 1 — App entry point.
//  Once you add the Firebase SDK via Swift Package Manager (Phase 2),
//  uncomment the `import FirebaseCore` line and the `FirebaseApp.configure()` call.
//

import SwiftUI
// import FirebaseCore

@main
struct RideBookingAppApp: App {

    // Central app-wide session/auth state (see Services/SessionManager.swift)
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var router = Router()

    init() {
        // FirebaseApp.configure()   // <-- uncomment in Phase 2 after adding GoogleService-Info.plist
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
