//
//  DriverHomeViewModel.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//
//  Drives DriverHomeView:
//   1. Online/Offline toggle — flips isAvailable + starts/stops live
//      location broadcasting (Phase 9) and ride matching.
//   2. While online, listens for nearby "requested" rides and surfaces the
//      closest one as `incomingRide` with a countdown timer.
//   3. Accept — safely assigns the ride to this driver (Firestore
//      transaction) and hands the rideId back so the view can navigate to
//      the active-ride screen. Reject — skips this ride locally and keeps
//      matching.
//

import Foundation
import CoreLocation
import FirebaseAuth

@MainActor
final class DriverHomeViewModel: ObservableObject {

    @Published var isOnline = false
    @Published var isTogglingOnline = false
    @Published var incomingRide: Ride?
    @Published var countdownRemaining: Int = Constants.Matching.requestTimeoutSeconds
    @Published var errorMessage: String?

    private var matchingTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var locationBroadcastTask: Task<Void, Never>?
    private var ignoredRideIds: Set<String> = []

    private let driverService = DriverService.shared
    private let locationManager = LocationManager.shared

    private var driverUid: String? { Auth.auth().currentUser?.uid }

    deinit {
        matchingTask?.cancel()
        countdownTask?.cancel()
        locationBroadcastTask?.cancel()
    }

    /// Call from the view's `.onAppear` — resumes matching if the driver is
    /// already online but paused matching while on an active ride.
    func onAppear() {
        guard isOnline, matchingTask == nil, let uid = driverUid else { return }
        startMatching(uid: uid)
    }

    // MARK: - Online / offline

    func toggleOnline() {
        Task {
            if isOnline {
                await goOffline()
            } else {
                await goOnline()
            }
        }
    }

    func goOnline() async {
        guard let uid = driverUid else { return }
        isTogglingOnline = true
        defer { isTogglingOnline = false }

        locationManager.requestPermissionIfNeeded()
        locationManager.startUpdating()

        do {
            try await driverService.goOnline(uid: uid, coordinate: locationManager.currentLocation)
            isOnline = true
            startMatching(uid: uid)
            locationBroadcastTask = driverService.startBroadcastingLocation(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goOffline() async {
        guard let uid = driverUid else { return }
        isTogglingOnline = true
        defer { isTogglingOnline = false }

        matchingTask?.cancel(); matchingTask = nil
        countdownTask?.cancel(); countdownTask = nil
        locationBroadcastTask?.cancel(); locationBroadcastTask = nil
        incomingRide = nil

        do {
            try await driverService.goOffline(uid: uid)
            isOnline = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Matching

    private func startMatching(uid: String) {
        matchingTask?.cancel()
        matchingTask = Task { [weak self] in
            guard let self else { return }

            // Wait briefly for a first GPS fix rather than silently giving up.
            var location = locationManager.currentLocation
            var attempts = 0
            while location == nil && attempts < 10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                location = locationManager.currentLocation
                attempts += 1
            }
            guard let driverLocation = location else {
                self.errorMessage = "Couldn't get your location — check Location permissions."
                return
            }

            let requestedRides = RideService.shared.observeRequestedRides()
            let nearby = driverService.nearbyRequestedRides(from: requestedRides, driverLocation: driverLocation)

            do {
                for try await rides in nearby {
                    guard !Task.isCancelled else { return }
                    self.handle(candidateRides: rides)
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handle(candidateRides rides: [Ride]) {
        // Already showing a request that's still valid? Leave it be.
        if let current = incomingRide, rides.contains(where: { $0.id == current.id }) {
            return
        }
        guard let next = rides.first(where: { ride in
            guard let id = ride.id else { return false }
            return !ignoredRideIds.contains(id)
        }) else {
            incomingRide = nil
            return
        }
        incomingRide = next
        startCountdown()
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownRemaining = Constants.Matching.requestTimeoutSeconds
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while self.countdownRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.countdownRemaining -= 1
            }
            guard !Task.isCancelled else { return }
            self.rejectRequest()
        }
    }

    // MARK: - Respond to a request

    func rejectRequest() {
        countdownTask?.cancel()
        if let id = incomingRide?.id {
            ignoredRideIds.insert(id)
        }
        incomingRide = nil
    }

    /// Returns the accepted ride's id on success so the view can navigate
    /// to the active-ride screen. Pauses matching while a ride is active.
    func acceptRequest() async -> String? {
        guard let ride = incomingRide, let rideId = ride.id, let uid = driverUid else { return nil }
        countdownTask?.cancel()

        do {
            try await driverService.acceptRide(rideId: rideId, driverId: uid)
            incomingRide = nil
            matchingTask?.cancel(); matchingTask = nil
            return rideId
        } catch {
            // Most likely another driver won the race — drop it and keep matching.
            errorMessage = error.localizedDescription
            ignoredRideIds.insert(rideId)
            incomingRide = nil
            return nil
        }
    }
}
