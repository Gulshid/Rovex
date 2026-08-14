//
//  DriverService.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  Everything the Driver side needs that isn't already covered by
//  RideService (ride documents) or UserService (the driver's own user
//  doc): going online/offline, broadcasting live location while online or
//  on a ride, filtering nearby "requested" rides client-side, and
//  progressing an accepted ride through to completion.
//

import Foundation
import CoreLocation
import FirebaseFirestore

final class DriverService {

    static let shared = DriverService()

    private let userService = UserService.shared
    private let rideService = RideService.shared

    private init() {}

    // MARK: - Phase 8 — Online / offline

    func goOnline(uid: String, coordinate: CLLocationCoordinate2D?) async throws {
        try await userService.setAvailability(uid: uid, isAvailable: true)
        if let coordinate {
            try await userService.updateCurrentLocation(uid: uid, coordinate: coordinate)
        }
    }

    func goOffline(uid: String) async throws {
        try await userService.setAvailability(uid: uid, isAvailable: false)
    }

    // MARK: - Phase 9 — Live location broadcast

    /// Starts a repeating background task that writes the driver's current
    /// device location to their Firestore user doc every
    /// `Constants.Tracking.driverLocationUpdateInterval` seconds, which is
    /// what lets the Rider's map show the driver moving live. Cancel the
    /// returned Task when the driver goes offline.
    func startBroadcastingLocation(uid: String) -> Task<Void, Never> {
        Task {
            while !Task.isCancelled {
                if let coordinate = await LocationManager.shared.currentLocation {
                    try? await userService.updateCurrentLocation(uid: uid, coordinate: coordinate)
                }
                try? await Task.sleep(
                    nanoseconds: UInt64(Constants.Tracking.driverLocationUpdateInterval * 1_000_000_000)
                )
            }
        }
    }

    // MARK: - Phase 8 — Matching

    /// Wraps a raw "all requested rides" stream (from RideService) and
    /// re-emits it filtered to rides whose pickup is within
    /// `Constants.Matching.searchRadiusKm` of `driverLocation`, closest
    /// first. `driverLocation` is captured once per call — good enough for
    /// a practice app; a production app would re-filter as the driver moves.
    func nearbyRequestedRides(
        from stream: AsyncThrowingStream<[Ride], Error>,
        driverLocation: CLLocationCoordinate2D
    ) -> AsyncThrowingStream<[Ride], Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await rides in stream {
                        let nearby = rides
                            .filter {
                                // Skip rides that have already been claimed
                                // by another driver (status may lag the
                                // driverId field by one snapshot cycle).
                                $0.driverId == nil &&
                                GeoUtils.distanceKm(driverLocation, $0.pickupLocation.geoPoint.clCoordinate)
                                    <= Constants.Matching.searchRadiusKm
                            }
                            .sorted {
                                GeoUtils.distanceKm(driverLocation, $0.pickupLocation.geoPoint.clCoordinate)
                                    < GeoUtils.distanceKm(driverLocation, $1.pickupLocation.geoPoint.clCoordinate)
                            }
                        continuation.yield(nearby)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Accept / progress a ride

    /// Safe accept — delegates to RideService's transaction so two drivers
    /// can never win the same ride.
    func acceptRide(rideId: String, driverId: String) async throws {
        try await rideService.acceptRide(rideId: rideId, driverId: driverId)
    }

    func startRide(rideId: String) async throws {
        try await rideService.startRide(rideId: rideId)
    }

    func completeRide(rideId: String) async throws {
        try await rideService.completeRide(rideId: rideId)
    }
}
