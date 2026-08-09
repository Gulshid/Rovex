//
//  UserService.swift
//  RideBookingApp
//
//  Phase 2/3 — Reads and updates documents in the `users` Firestore collection.
//

import Foundation
import FirebaseFirestore

@MainActor
final class UserService {

    static let shared = UserService()
    private init() {}

    private let db = Firestore.firestore()

    func fetchUser(uid: String) async throws -> AppUser {
        let snapshot = try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .getDocument()
        guard let user = try? snapshot.data(as: AppUser.self) else {
            throw NSError(
                domain: "UserService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "User profile not found."]
            )
        }
        return user
    }

    func updateProfile(uid: String, name: String, phone: String?) async throws {
        var data: [String: Any] = ["name": name]
        data["phone"] = phone ?? NSNull()
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(data)
    }

    func updatePhotoURL(uid: String, url: String) async throws {
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(["photoURL": url])
    }

    func updateVehicle(uid: String, vehicle: VehicleDetails) async throws {
        let data = try Firestore.Encoder().encode(vehicle)
        try await db.collection(Constants.Firestore.usersCollection)
            .document(uid)
            .updateData(["vehicle": data])
    }
}
