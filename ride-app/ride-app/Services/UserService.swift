//
//  UserService.swift
//  RideBookingApp
//
//  Phase 3 — fetch/update the current user's Firestore document.
//  UPDATED in Phase 5 — added Cloudinary-URL-specific writes for
//  profile photo, vehicle photo, and license photo. Everything lives
//  on the single `users` document (see AppUser in Models/User.swift) —
//  there is no separate `drivers` collection, so vehicle fields are
//  written with dotted field paths onto the same doc.
//
//  UPDATED in Phase 8 — added driver isAvailable/currentLocation writes
//  used for "go online" + nearby-ride matching.
//  UPDATED in Phase 9 — added `observeUser`, a live snapshot-listener
//  stream so the Rider side can watch a specific driver's `currentLocation`
//  field update in real time (that's how the live tracking map moves).
//

import Foundation
import CoreLocation
import FirebaseFirestore

final class UserService {

    static let shared = UserService()
    private let db = Firestore.firestore()

    private init() {}

    func fetchUser(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func updateProfileFields(uid: String, fields: [String: Any]) async throws {
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(fields)
    }

    // MARK: - Phase 5

    /// Saves the Cloudinary secure_url for a rider/driver's profile photo.
    func updateProfilePhotoURL(uid: String, url: String) async throws {
        try await updateProfileFields(uid: uid, fields: ["photoURL": url])
    }

    /// Saves the Cloudinary secure_url for a driver's vehicle photo.
    /// Nested under `vehicle.vehiclePhotoURL` on the user doc.
    func updateVehiclePhotoURL(uid: String, url: String) async throws {
        try await updateProfileFields(uid: uid, fields: ["vehicle.vehiclePhotoURL": url])
    }

    /// Saves the Cloudinary secure_url for a driver's license document photo.
    /// Nested under `vehicle.licenseURL` on the user doc.
    func updateDriverLicenseURL(uid: String, url: String) async throws {
        try await updateProfileFields(uid: uid, fields: ["vehicle.licenseURL": url])
    }

    // MARK: - Phase 8 — Driver availability & location

    /// Flips a driver's `isAvailable` flag (Go Online / Go Offline).
    func setAvailability(uid: String, isAvailable: Bool) async throws {
        try await updateProfileFields(uid: uid, fields: ["isAvailable": isAvailable])
    }

    /// Writes the driver's current coordinate onto their user doc. Called
    /// once on "Go Online" and then repeatedly by
    /// DriverService.startBroadcastingLocation (Phase 9) so the Rider's map
    /// can track them live.
    func updateCurrentLocation(uid: String, coordinate: CLLocationCoordinate2D) async throws {
        let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        try await updateProfileFields(uid: uid, fields: ["currentLocation": geoPoint])
    }

    // MARK: - Phase 9 — Live user doc updates

    /// Streams live updates to a single user's document — used by the
    /// Rider to watch their assigned driver's `currentLocation` move in
    /// real time. The stream finishes when the caller cancels the
    /// enclosing Task (e.g. the ride completes or the view disappears).
    func observeUser(uid: String) -> AsyncThrowingStream<AppUser, Error> {
        AsyncThrowingStream { continuation in
            let listener = db.collection(Constants.Firestore.usersCollection)
                .document(uid)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot, snapshot.exists else { return }
                    do {
                        let user = try snapshot.data(as: AppUser.self)
                        continuation.yield(user)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
