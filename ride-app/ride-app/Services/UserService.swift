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

import Foundation
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
}
