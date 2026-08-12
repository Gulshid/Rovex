//
//  PushNotificationService.swift
//  RideBookingApp
//
//  Phase 11 — Push Notifications (FCM)
//
//  Two things live here, matching the roadmap's two tracks:
//
//  1. Remote push via Firebase Cloud Messaging — requests notification
//     permission, registers for remote notifications, and saves the FCM
//     device token onto the user's own Firestore doc (`fcmToken`, already
//     modeled on AppUser since Phase 4). Actually *sending* a push needs a
//     backend trigger — see the optional Cloud Function sketch in
//     /functions/index.js at the repo root; wiring that up is optional
//     per the roadmap.
//
//  2. Local notifications as the practice-app fallback the roadmap calls
//     out explicitly ("Add local notifications as a fallback for simple
//     status changes if you skip Cloud Functions initially") — these fire
//     entirely on-device from BookRideViewModel/DriverHomeViewModel when a
//     ride's status changes, so status alerts work end-to-end without
//     standing up Cloud Functions at all.
//
//  Tapping either kind of notification deep-links back into the right
//  screen via `pendingDeepLink`, which RootView observes.
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth

/// What a tapped notification should navigate to. RootView turns this into
/// a `router.push(...)`.
struct NotificationDeepLink: Equatable {
    enum Kind: Equatable {
        case rideTracking      // rider tapped a status notification
        case activeDriverRide  // driver tapped a status notification
    }
    let kind: Kind
    let rideId: String
}

@MainActor
final class PushNotificationService: NSObject, ObservableObject {

    static let shared = PushNotificationService()

    /// Set when a notification is tapped; RootView consumes and clears it.
    @Published var pendingDeepLink: NotificationDeepLink?

    private let userService = UserService.shared
    private var hasConfigured = false

    private override init() {
        super.init()
    }

    // MARK: - Setup (call once, from AppDelegate)

    func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    // MARK: - Permission + registration

    /// Call after the user is signed in (SessionManager does this). Asks
    /// for permission if not already determined, registers for remote
    /// notifications, and — once FCM hands back a token via the delegate
    /// callback below — saves it to Firestore.
    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                if settings.authorizationStatus == .authorized {
                    Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
                }
                return
            }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                Task { @MainActor in UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    /// Saves whatever FCM token we currently have onto the just-logged-in
    /// user's doc — covers the case where the token arrived before login.
    func syncTokenToCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = Messaging.messaging().fcmToken else { return }
        Task { try? await userService.updateFCMToken(uid: uid, token: token) }
    }

    // MARK: - Local notifications (Phase 11 fallback)

    /// Fires an on-device notification for a ride status change. Safe to
    /// call while the app is foregrounded too — `willPresent` below still
    /// shows it, which is convenient for testing on the simulator.
    func notifyRideStatusChanged(rideId: String, status: RideStatus, forDriver: Bool) {
        let (title, body) = copy(for: status, forDriver: forDriver)
        guard let title, let body else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = [
            "rideId": rideId,
            "role": forDriver ? "driver" : "rider"
        ]

        let request = UNNotificationRequest(
            identifier: "ride-\(rideId)-\(status.rawValue)",
            content: content,
            trigger: nil // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func copy(for status: RideStatus, forDriver: Bool) -> (String?, String?) {
        if forDriver {
            switch status {
            case .accepted: return ("Ride accepted", "You're on your way to pick up the rider.")
            case .ongoing: return ("Ride started", "Heading to the drop-off now.")
            case .completed: return ("Ride completed", "Nice work — ready for the next request.")
            case .cancelled: return ("Ride cancelled", "The rider cancelled this ride.")
            default: return (nil, nil)
            }
        } else {
            switch status {
            case .accepted: return ("Driver on the way", "Your driver accepted the ride and is heading to pickup.")
            case .ongoing: return ("Ride started", "You're on your way to the drop-off.")
            case .completed: return ("Ride completed", "Thanks for riding — your receipt is ready.")
            case .cancelled: return ("Ride cancelled", "Your ride was cancelled.")
            default: return (nil, nil)
            }
        }
    }

    /// New nearby request while the driver is online — used by
    /// DriverHomeViewModel so a backgrounded driver still gets alerted.
    func notifyIncomingRideRequest(rideId: String) {
        let content = UNMutableNotificationContent()
        content.title = "New ride request"
        content.body = "A rider nearby is looking for a ride."
        content.sound = .default
        content.userInfo = ["rideId": rideId, "role": "driver-incoming"]

        let request = UNNotificationRequest(
            identifier: "incoming-\(rideId)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {

    /// Show banners even while the app is in the foreground — makes local
    /// notifications actually visible while testing on device/simulator.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let rideId = userInfo["rideId"] as? String,
              let role = userInfo["role"] as? String else { return }

        await MainActor.run {
            switch role {
            case "driver", "driver-incoming":
                self.pendingDeepLink = NotificationDeepLink(kind: .activeDriverRide, rideId: rideId)
            default:
                self.pendingDeepLink = NotificationDeepLink(kind: .rideTracking, rideId: rideId)
            }
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            guard let uid = Auth.auth().currentUser?.uid else { return }
            try? await self.userService.updateFCMToken(uid: uid, token: fcmToken)
        }
    }
}
