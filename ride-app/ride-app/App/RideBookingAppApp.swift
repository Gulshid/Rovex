//
//  RideBookingAppApp.swift
//  RideBookingApp
//
//  Phase 2 — App entry point. Firebase is now configured on launch.
//  Phase 11 — Wires in AppDelegate (via @UIApplicationDelegateAdaptor) so
//  FCM/APNs callbacks have somewhere to land, and hands the
//  PushNotificationService down as an environment object so RootView can
//  react to a tapped-notification deep link.
//

import SwiftUI
import FirebaseCore

@main
struct RideBookingAppApp: App {

    // Central app-wide session/auth state (see Services/SessionManager.swift)
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var router = Router()

    // Phase 11 — UIKit bridge for FCM/APNs delegate callbacks
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var pushService = PushNotificationService.shared

    init() {
        // AppDelegate.application(_:didFinishLaunchingWithOptions:) also
        // calls FirebaseApp.configure() — guarded there against double
        // configuration, so this stays here too for anyone previewing
        // views without the delegate attached.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        print("✅ RideBookingApp launched — environment: \(AppEnvironment.current)")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(router)
                .environmentObject(pushService)
        }
    }
}

