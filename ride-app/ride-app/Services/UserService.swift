//
//  UserService.swift
//  RideBookingApp
//
//  UPDATED in Phase 5.
//  Phase 3 already has profile read/update logic — this adds the
//  Cloudinary-URL-specific writes for profile photo, vehicle photo,
//  and license photo. Merge these methods into your existing
//  UserService.swift instead of overwriting it, if you already
//  have other methods (fetchUser, updateProfile, etc.) in there.
//

import Foundation
import FirebaseFirestore

final class UserService {

    static let shared = UserService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Existing from Phase 3 (kept here for reference/context)

    func fetchUser(uid: String) async throws -> User {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try snapshot.data(as: User.self)
    }

    func updateProfileFields(uid: String, fields: [String: Any]) async throws {
        try await db.collection("users").document(uid).updateData(fields)
    }

    // MARK: - New in Phase 5

    /// Saves the Cloudinary secure_url for a rider/driver's profile photo.
    func updateProfilePhotoURL(uid: String, url: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "photoURL": url
        ])
    }

    /// Saves the Cloudinary secure_url for a driver's license document photo.
    /// Lives on the `drivers` collection (see Driver.swift, Phase 4).
    func updateDriverLicenseURL(uid: String, url: String) async throws {
        try await db.collection("drivers").document(uid).updateData([
            "licenseURL": url
        ])
    }

    /// Saves the Cloudinary secure_url for a driver's vehicle photo.
    /// Nested under the `vehicle` map on the driver doc (see VehicleInfo in Driver.swift).
    func updateVehiclePhotoURL(uid: String, url: String) async throws {
        try await db.collection("drivers").document(uid).updateData([
            "vehicle.vehiclePhotoURL": url
        ])
    }
}
