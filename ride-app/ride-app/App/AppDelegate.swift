//
//  AppDelegate.swift
//  RideBookingApp
//
//  Phase 11 — Push Notifications (FCM)
//
//  SwiftUI's App protocol has no hook for
//  application(_:didRegisterForRemoteNotificationsWithDeviceToken:), which
//  FCM needs in order to hand the APNs token to Firebase — so a thin
//  UIApplicationDelegate is wired in via @UIApplicationDelegateAdaptor in
//  RideBookingAppApp. Everything else stays in PushNotificationService.
//
//  NOTE — this alone doesn't turn on push. In Xcode: select the app
//  target → Signing & Capabilities → "+ Capability" → add "Push
//  Notifications" (this generates ride-app.entitlements and wires it up
//  automatically) and add "Background Modes" → check "Remote
//  notifications". You'll also need an APNs Auth Key uploaded to your
//  Firebase project (Project Settings → Cloud Messaging) — see
//  https://firebase.google.com/docs/cloud-messaging/ios/client
//

import UIKit
import FirebaseCore
import FirebaseMessaging

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Task { @MainActor in
            PushNotificationService.shared.configure()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("⚠️ Failed to register for remote notifications: \(error.localizedDescription)")
    }
}
