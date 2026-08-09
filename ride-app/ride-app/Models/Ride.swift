//
//  Ride.swift
//  RideBookingApp
//
//  Phase 4 - Firestore Data Modeling
//  Matches the `rides` collection.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum RideStatus: String, Codable {
    case requested
    case accepted
    case ongoing
    case completed
    case cancelled
    case scheduled     // Phase 14 - scheduled rides
}

struct RideLocation: Codable, Equatable {
    var address: String
    var geoPoint: GeoPoint
}

struct FareBreakdown: Codable, Equatable {
    var baseFare: Double
    var distanceFare: Double
    var timeFare: Double
    var total: Double
    var distanceKm: Double
    var durationMin: Double
    var paymentMethod: String   // "cash" | "card" | "wallet"
}

struct Ride: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var riderId: String
    var driverId: String?
    var pickupLocation: RideLocation
    var dropoffLocation: RideLocation
    var status: RideStatus
    var vehicleType: VehicleType = .economy
    var estimatedFare: Double?
    var fare: FareBreakdown?
    var scheduledFor: Timestamp?        // Phase 14 - scheduled rides
    var promoCode: String?              // Phase 14 - promo codes

    @ServerTimestamp var createdAt: Timestamp?
    var acceptedAt: Timestamp?
    var startedAt: Timestamp?
    var completedAt: Timestamp?
    var cancelledAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case riderId
        case driverId
        case pickupLocation
        case dropoffLocation
        case status
        case vehicleType
        case estimatedFare
        case fare
        case scheduledFor
        case promoCode
        case createdAt
        case acceptedAt
        case startedAt
        case completedAt
        case cancelledAt
    }
}
