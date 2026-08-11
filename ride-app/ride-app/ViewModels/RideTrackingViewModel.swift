//
//  RideTrackingViewModel.swift
//  RideBookingApp
//
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  BookRideViewModel already tracks the driver's live location inline for
//  a ride that was just booked in this session (see its
//  `driverLocation`/`etaMinutes`). This view model covers the other case —
//  opening live tracking for a ride by id alone, which is what
//  Router.AppRoute.rideTracking(rideId:) is for (e.g. re-opening an
//  in-progress ride from Ride History in Phase 12, or after a relaunch).
//

import Foundation
import CoreLocation

@MainActor
final class RideTrackingViewModel: ObservableObject {

    let rideId: String

    @Published private(set) var ride: Ride?
    @Published private(set) var driver: AppUser?
    @Published private(set) var driverLocation: CLLocationCoordinate2D?
    @Published private(set) var etaMinutes: Double?
    @Published var errorMessage: String?

    private var rideTask: Task<Void, Never>?
    private var driverLocationTask: Task<Void, Never>?

    private let rideService = RideService.shared
    private let userService = UserService.shared
    private let directionsService = DirectionsService.shared

    init(rideId: String) {
        self.rideId = rideId
    }

    deinit {
        rideTask?.cancel()
        driverLocationTask?.cancel()
    }

    func start() {
        guard rideTask == nil else { return }
        rideTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await updated in rideService.observeRide(rideId: rideId) {
                    guard !Task.isCancelled else { return }
                    self.ride = updated
                    if let driverId = updated.driverId {
                        self.startObservingDriver(driverId: driverId)
                    }
                    if updated.status == .completed || updated.status == .cancelled {
                        self.driverLocationTask?.cancel()
                        self.driverLocationTask = nil
                    }
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func startObservingDriver(driverId: String) {
        guard driverLocationTask == nil else { return }
        driverLocationTask = Task { [weak self] in
            guard let self else { return }
            if driver?.id != driverId {
                driver = try? await userService.fetchUser(uid: driverId)
            }
            do {
                for try await user in userService.observeUser(uid: driverId) {
                    guard !Task.isCancelled else { return }
                    guard let location = user.currentLocation else { continue }
                    let coordinate = location.clCoordinate
                    self.driverLocation = coordinate
                    await self.refreshETA(from: coordinate)
                }
            } catch {
                // Live tracking is best-effort — don't surface as a hard error.
            }
        }
    }

    private func refreshETA(from driverCoordinate: CLLocationCoordinate2D) async {
        guard let ride else { return }
        let destination = (ride.status == .ongoing)
            ? ride.dropoffLocation.geoPoint.clCoordinate
            : ride.pickupLocation.geoPoint.clCoordinate

        if let preview = try? await directionsService.route(from: driverCoordinate, to: destination) {
            etaMinutes = preview.durationMin
        }
    }
}
