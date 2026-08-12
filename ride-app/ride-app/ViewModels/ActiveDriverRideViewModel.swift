//
//  ActiveDriverRideViewModel.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  Drives ActiveDriverRideView from the moment a driver accepts a ride
//  through to completion:
//   accepted (en route to pickup) → "Start Ride" → ongoing (en route to
//   drop-off) → "Complete Ride" → completed.
//
//  Live location broadcasting itself is already running continuously via
//  DriverHomeViewModel's `locationBroadcastTask` (started on "Go Online"
//  and kept alive through a ride) — this view model just observes the ride
//  document and recalculates ETA to whichever stop is next.
//
//  UPDATED in Phase 10 — completeRide() now uses RideService's updated
//  signature, which writes and returns a real FareBreakdown receipt; that
//  final `fare` is what ActiveDriverRideView shows on the "Ride completed"
//  screen instead of just the pre-ride estimate.
//
//  UPDATED in Phase 11 — fires a local notification fallback on ride
//  status transitions (ongoing/completed/cancelled) the same way the
//  rider side does, in case the driver has backgrounded the app.
//

import Foundation
import CoreLocation

@MainActor
final class ActiveDriverRideViewModel: ObservableObject {

    let rideId: String

    @Published private(set) var ride: Ride?
    @Published private(set) var rider: AppUser?
    @Published private(set) var etaMinutes: Double?
    @Published var errorMessage: String?
    @Published var isUpdatingStatus = false

    private var observeTask: Task<Void, Never>?
    private let rideService = RideService.shared
    private let userService = UserService.shared
    private let directionsService = DirectionsService.shared
    private let locationManager = LocationManager.shared

    private var lastNotifiedStatus: RideStatus?

    init(rideId: String) {
        self.rideId = rideId
    }

    deinit {
        observeTask?.cancel()
    }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await updated in rideService.observeRide(rideId: rideId) {
                    guard !Task.isCancelled else { return }
                    self.ride = updated
                    self.notifyStatusChangeIfNeeded(updated)
                    await self.loadRiderIfNeeded()
                    await self.refreshETA()
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func notifyStatusChangeIfNeeded(_ ride: Ride) {
        guard ride.status != lastNotifiedStatus else { return }
        lastNotifiedStatus = ride.status
        guard [.ongoing, .completed, .cancelled].contains(ride.status) else { return }
        PushNotificationService.shared.notifyRideStatusChanged(
            rideId: ride.id ?? rideId,
            status: ride.status,
            forDriver: true
        )
    }

    private func loadRiderIfNeeded() async {
        guard let riderId = ride?.riderId, rider?.id != riderId else { return }
        rider = try? await userService.fetchUser(uid: riderId)
    }

    private func refreshETA() async {
        guard let ride, let driverLocation = locationManager.currentLocation else { return }
        let destination = isOngoing
            ? ride.dropoffLocation.geoPoint.clCoordinate
            : ride.pickupLocation.geoPoint.clCoordinate

        if let preview = try? await directionsService.route(from: driverLocation, to: destination) {
            etaMinutes = preview.durationMin
        }
    }

    var isEnRouteToPickup: Bool { ride?.status == .accepted }
    var isOngoing: Bool { ride?.status == .ongoing }
    var isCompleted: Bool { ride?.status == .completed }
    var isCancelled: Bool { ride?.status == .cancelled }

    func startRide() async {
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        do {
            try await rideService.startRide(rideId: rideId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeRide() async {
        isUpdatingStatus = true
        defer { isUpdatingStatus = false }
        do {
            let completed = try await rideService.completeRide(rideId: rideId)
            ride = completed
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
