//
//  Driver.swift
//  RideBookingApp
//
//  Phase 4 - Firestore Data Modeling
//  Matches the `drivers` collection (one doc per driver, id == uid,
//  same id as the matching `users` doc).
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

struct VehicleInfo: Codable, Equatable {
    var model: String
    var plateNumber: String
    var color: String
    var seats: Int
    var vehicleType: VehicleType = .economy
    var vehiclePhotoURL: String?     // set by Cloudinary upload (Phase 5)
}

enum VehicleType: String, Codable, CaseIterable {
    case economy
    case comfort
    case xl
}

struct Driver: Codable, Identifiable, Equatable {
    @DocumentID var id: String?          // == uid, same as User.id
    var vehicle: VehicleInfo
    var licenseURL: String?              // set by Cloudinary upload (Phase 5)
    var isAvailable: Bool = false
    var currentLocation: GeoPoint?
    var rating: Double = 5.0
    var ratingCount: Int = 0
    @ServerTimestamp var updatedAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicle
        case licenseURL
        case isAvailable
        case currentLocation
        case rating
        case ratingCount
        case updatedAt
    }
}
