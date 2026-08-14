//
//  User.swift
//  RideBookingApp
//
//  Phase 2/3 — AppUser / UserRole / VehicleDetails (single flat `users`
//  collection design — a rider or driver doc, driver-only fields nested
//  under `vehicle`). This is the canonical model the rest of the app
//  (AuthService, SessionManager, ProfileView, EditProfileView,
//  VehicleDetailsView, HomeView) already depends on.
//
//  UPDATED in Phase 4 — added currentLocation/rating/ratingCount so
//  Phase 8/9 driver-matching and Phase 12 ratings can query directly off
//  the users collection, plus Phase 14 groundwork fields. No existing
//  field was renamed or removed, so old documents keep decoding fine.
//
//  UPDATED in Phase 14 — homeAddress/workAddress (already reserved since
//  Phase 4) are now actually wired up via FavoriteLocationsView. Added
//  emergencyContactName/emergencyContactPhone for the SOS button to read
//  from (optional — SOSButton's share sheet works fine without one set,
//  the person just has to pick a recipient manually in the share sheet).
//

import Foundation
import FirebaseFirestore

enum UserRole: String, Codable {
    case rider
    case driver
}

struct VehicleDetails: Codable, Equatable {
    var model: String
    var plateNumber: String
    var color: String
    var seats: Int
    var licenseURL: String?
    var vehiclePhotoURL: String?
    var vehicleType: VehicleType?     // Phase 14 — Economy/Comfort/XL, optional so old docs still decode
}

struct AppUser: Codable, Identifiable, Equatable {
    @DocumentID var id: String?           // Firestore doc id == Firebase Auth uid
    var name: String
    var email: String
    var role: UserRole
    var phone: String?
    var photoURL: String?
    var isAvailable: Bool?                // drivers only
    var vehicle: VehicleDetails?          // drivers only
    var createdAt: Date?

    // Phase 4 — driver matching (Phase 8/9) & ratings (Phase 12)
    var currentLocation: GeoPoint?
    var rating: Double?
    var ratingCount: Int?

    // Phase 14 — favorites, wallet, push notifications, emergency contact
    var homeAddress: String?
    var homeAddressGeoPoint: GeoPoint?
    var workAddress: String?
    var workAddressGeoPoint: GeoPoint?
    var walletBalance: Double?
    var fcmToken: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role, phone, photoURL, isAvailable, vehicle, createdAt
        case currentLocation, rating, ratingCount
        case homeAddress, homeAddressGeoPoint, workAddress, workAddressGeoPoint
        case walletBalance, fcmToken
        case emergencyContactName, emergencyContactPhone
    }
}
