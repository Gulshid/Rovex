//
//  FareEstimator.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Simple base + distance-rate + time-rate formula, exactly as sketched
//  in the Phase 10 roadmap notes, pulled forward so Phase 7 can show a
//  believable "estimated fare" on the Book a Ride screen before the ride
//  even exists. Phase 10 will reuse this exact estimate to compute the
//  final receipt.
//
//  Rates live in Constants.Fare so they're tweakable in one place.
//

import Foundation

enum FareEstimator {

    struct Estimate {
        let baseFare: Double
        let distanceFare: Double
        let timeFare: Double
        let total: Double
    }

    /// - Parameters:
    ///   - distanceKm: route distance in kilometers
    ///   - durationMin: route duration in minutes
    ///   - vehicleType: Economy / Comfort / XL — applies a fare multiplier
    static func estimate(
        distanceKm: Double,
        durationMin: Double,
        vehicleType: VehicleType
    ) -> Estimate {
        let rates = Constants.Fare.rates(for: vehicleType)

        let base = rates.baseFare
        let distanceFare = distanceKm * rates.perKm
        let timeFare = durationMin * rates.perMinute

        let subtotal = base + distanceFare + timeFare
        let total = max(subtotal, rates.minimumFare)

        return Estimate(
            baseFare: base,
            distanceFare: distanceFare,
            timeFare: timeFare,
            total: (total * 100).rounded() / 100 // round to cents
        )
    }
}
