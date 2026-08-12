//
//  Ride.swift
//  RideBookingApp
//
//  Phase 4 - Firestore Data Modeling
//  Matches the `rides` collection.
//
//  UPDATED - VehicleType now lives here (was previously defined in a
//  separate Driver.swift that duplicated the app's actual user model —
//  removed). AppUser.vehicle.vehicleType (Models/User.swift) references
//  this same enum.
//
//  UPDATED in Phase 10 — added `distanceKm`/`durationMin` (captured once,
//  at booking time, from the route preview already computed in Phase 6/7)
//  and `paymentMethod` (chosen on the new Payment Method screen). Both are
//  needed so RideService.completeRide can recompute a real FareBreakdown
//  receipt with FareEstimator using the *same* trip numbers the rider saw
//  when they booked, instead of only ever having a single `estimatedFare`
//  total with no breakdown. Optional with defaults so old ride documents
//  written before Phase 10 still decode fine.
//

import Foundation
import FirebaseFirestore

enum VehicleType: String, Codable, CaseIterable {
    case economy
    case comfort
    case xl
}

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
    var distanceKm: Double?             // Phase 10 - captured at booking time
    var durationMin: Double?            // Phase 10 - captured at booking time
    var paymentMethod: PaymentMethod = .cash   // Phase 10 - chosen at booking time
    var fare: FareBreakdown?            // Phase 10 - final receipt, written on completion
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
        case distanceKm
        case durationMin
        case paymentMethod
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
