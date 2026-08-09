//
//  User.swift
//  RideBookingApp
//
//  Phase 2/3 — Codable models backing the `users` Firestore collection.
//  Full schema documentation arrives in Phase 4; this is the working subset
//  needed for Auth (Phase 2) and Profile/Vehicle onboarding (Phase 3).
//

import Foundation
import FirebaseFirestore

enum UserRole: String, Codable, CaseIterable, Hashable {
    case rider
    case driver
}

struct VehicleDetails: Codable, Equatable, Hashable {
    var model: String
    var plateNumber: String
    var color: String
    var seats: Int
    var licenseURL: String?
    var vehiclePhotoURL: String?
}

/// Matches a document in the `users` Firestore collection.
struct AppUser: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var role: UserRole
    var phone: String?
    var photoURL: String?
    /// Drivers only — toggled online/offline starting Phase 8.
    var isAvailable: Bool?
    /// Drivers only — filled in during Phase 3 vehicle onboarding.
    var vehicle: VehicleDetails?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case role
        case phone
        case photoURL
        case isAvailable
        case vehicle
        case createdAt
    }
}
