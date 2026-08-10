//
//  BookRideViewModel.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Drives BookRideView end-to-end:
//   1. vehicle type selection + live fare estimate (idle)
//   2. "Confirm Ride" creates the Firestore ride doc (booking)
//   3. a live Firestore listener drives (searching → driver info → active/cancelled)
//   4. Cancel Ride updates status back to cancelled
//

import Foundation
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
final class BookRideViewModel: ObservableObject {

    // MARK: - Trip summary (passed in from MapBookingView)

    let pickupAddress: String
    let pickupCoordinate: CLLocationCoordinate2D?
    let dropoffAddress: String
    let dropoffCoordinate: CLLocationCoordinate2D?
    let distanceKm: Double
    let durationMin: Double

    // MARK: - Vehicle + fare

    @Published var selectedVehicleType: VehicleType = .economy

    var fareEstimate: FareEstimator.Estimate {
        FareEstimator.estimate(distanceKm: distanceKm, durationMin: durationMin, vehicleType: selectedVehicleType)
    }

    // MARK: - Ride lifecycle state

    enum BookingPhase: Equatable {
        case idle              // choosing vehicle type, not booked yet
        case booking            // "Confirm Ride" tapped, writing to Firestore
        case searching           // status == .requested, waiting for a driver
        case driverAssigned      // status == .accepted
        case ongoing              // status == .ongoing
        case completed
        case cancelled
        case failed(String)
    }

    @Published private(set) var phase: BookingPhase = .idle
    @Published private(set) var activeRide: Ride?
    @Published private(set) var assignedDriver: AppUser?

    @Published var showCancelConfirmation = false

    private var observeTask: Task<Void, Never>?
    private let rideService = RideService.shared
    private let userService = UserService.shared

    init(
        pickupAddress: String,
        pickupCoordinate: CLLocationCoordinate2D?,
        dropoffAddress: String,
        dropoffCoordinate: CLLocationCoordinate2D?,
        distanceKm: Double?,
        durationMin: Double?
    ) {
        self.pickupAddress = pickupAddress
        self.pickupCoordinate = pickupCoordinate
        self.dropoffAddress = dropoffAddress
        self.dropoffCoordinate = dropoffCoordinate
        self.distanceKm = distanceKm ?? 0
        self.durationMin = durationMin ?? 0
    }

    deinit {
        observeTask?.cancel()
    }

    var canConfirmRide: Bool {
        pickupCoordinate != nil && dropoffCoordinate != nil
    }

    // MARK: - Confirm ride

    func confirmRide() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            phase = .failed("You must be signed in to book a ride.")
            return
        }
        guard let pickupCoordinate, let dropoffCoordinate else {
            phase = .failed("Missing pickup or drop-off location.")
            return
        }

        phase = .booking

        let pickup = RideLocation(address: pickupAddress, geoPoint: GeoPoint(
            latitude: pickupCoordinate.latitude, longitude: pickupCoordinate.longitude
        ))
        let dropoff = RideLocation(address: dropoffAddress, geoPoint: GeoPoint(
            latitude: dropoffCoordinate.latitude, longitude: dropoffCoordinate.longitude
        ))

        do {
            let rideId = try await rideService.requestRide(
                riderId: uid,
                pickup: pickup,
                dropoff: dropoff,
                vehicleType: selectedVehicleType,
                estimatedFare: fareEstimate.total
            )
            phase = .searching
            observeRide(rideId: rideId)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Live ride status

    private func observeRide(rideId: String) {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }
            do {
                for try await ride in rideService.observeRide(rideId: rideId) {
                    guard !Task.isCancelled else { return }
                    await self.handle(ride)
                }
            } catch {
                if !Task.isCancelled {
                    self.phase = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func handle(_ ride: Ride) async {
        activeRide = ride

        switch ride.status {
        case .requested:
            phase = .searching
        case .accepted:
            phase = .driverAssigned
            await loadDriver(driverId: ride.driverId)
        case .ongoing:
            phase = .ongoing
        case .completed:
            phase = .completed
        case .cancelled:
            phase = .cancelled
        case .scheduled:
            phase = .searching
        }
    }

    private func loadDriver(driverId: String?) async {
        guard let driverId, assignedDriver?.id != driverId else { return }
        assignedDriver = try? await userService.fetchUser(uid: driverId)
    }

    // MARK: - Cancel

    func cancelRide() async {
        guard let rideId = activeRide?.id else { return }
        do {
            try await rideService.cancelRide(rideId: rideId)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
