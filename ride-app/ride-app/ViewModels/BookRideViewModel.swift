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
//  UPDATED in Phase 9 — once a driver is assigned, also observes the
//  driver's user doc for live `currentLocation` updates (driverLocation)
//  and recalculates ETA (etaMinutes) as it changes, so
//  DriverAssignedRideView can show a moving car on the map.
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

    // Phase 9 — live driver location + ETA, shown on DriverAssignedRideView's map
    @Published private(set) var driverLocation: CLLocationCoordinate2D?
    @Published private(set) var etaMinutes: Double?

    @Published var showCancelConfirmation = false

    private var observeTask: Task<Void, Never>?
    private var driverLocationTask: Task<Void, Never>?
    private let rideService = RideService.shared
    private let userService = UserService.shared
    private let directionsService = DirectionsService.shared

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
        driverLocationTask?.cancel()
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
            driverLocationTask?.cancel()
            driverLocationTask = nil
        case .cancelled:
            phase = .cancelled
            driverLocationTask?.cancel()
            driverLocationTask = nil
        case .scheduled:
            phase = .searching
        }
    }

    private func loadDriver(driverId: String?) async {
        guard let driverId else { return }
        if assignedDriver?.id != driverId {
            assignedDriver = try? await userService.fetchUser(uid: driverId)
        }
        startObservingDriverLocation(driverId: driverId)
    }

    // MARK: - Phase 9 — Live driver location + ETA

    private func startObservingDriverLocation(driverId: String) {
        guard driverLocationTask == nil else { return }
        driverLocationTask = Task { [weak self] in
            guard let self else { return }
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
        let destination: CLLocationCoordinate2D?
        switch phase {
        case .driverAssigned:
            destination = pickupCoordinate
        case .ongoing:
            destination = dropoffCoordinate
        default:
            destination = nil
        }
        guard let destination else { return }
        if let preview = try? await directionsService.route(from: driverCoordinate, to: destination) {
            etaMinutes = preview.durationMin
        }
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
