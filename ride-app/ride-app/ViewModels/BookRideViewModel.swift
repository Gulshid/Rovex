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
//  UPDATED in Phase 10 — added `selectedPaymentMethod` (chosen on the new
//  Payment Method screen, sent along with the ride request) and a
//  one-time wallet charge triggered the moment the ride's own listener
//  observes it flip to `.completed`. Charging happens here — on the
//  rider's own device/session — rather than on the driver's, because
//  firestore.rules only lets a user write to their own /users/{uid} doc
//  (see WalletService's header comment for the full reasoning).
//
//  UPDATED in Phase 11 — fires a local notification (PushNotificationService)
//  on each ride-status transition the rider observes, so "Driver on the
//  way" / "Ride started" / "Ride completed" alerts work without a Cloud
//  Functions backend.
//
//  UPDATED in Phase 14 — added promo code apply/remove (validated via
//  PromoCodeService, discount applied to `discountedTotal` and passed as
//  the ride's actual `estimatedFare`) and `scheduleRide`, an alternate
//  path to `confirmRide` that writes a "scheduled" ride via
//  RideService.scheduleRide instead of an immediate "requested" one, and
//  moves to a new `.scheduledConfirmation` phase rather than starting the
//  usual live-status listener (a scheduled ride has nothing to observe
//  yet — it isn't a real request until RideService.activateDueScheduledRides
//  flips it over at its scheduled time).
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

    // MARK: - Vehicle + fare + payment

    @Published var selectedVehicleType: VehicleType = .economy
    @Published var selectedPaymentMethod: PaymentMethod = .cash

    var fareEstimate: FareEstimator.Estimate {
        FareEstimator.estimate(distanceKm: distanceKm, durationMin: durationMin, vehicleType: selectedVehicleType)
    }

    // MARK: - Phase 14 — Promo code

    @Published var promoCodeInput: String = ""
    @Published private(set) var appliedPromoCode: PromoCode?
    @Published private(set) var isApplyingPromoCode = false
    @Published var promoCodeError: String?

    /// The total actually charged once a valid promo code is applied —
    /// this, not fareEstimate.total, is what gets sent to
    /// RideService.requestRide/scheduleRide as `estimatedFare`.
    var discountedTotal: Double {
        guard let appliedPromoCode else { return fareEstimate.total }
        return fareEstimate.total - appliedPromoCode.discountAmount(onTotal: fareEstimate.total)
    }

    func applyPromoCode() async {
        promoCodeError = nil
        isApplyingPromoCode = true
        defer { isApplyingPromoCode = false }
        do {
            appliedPromoCode = try await PromoCodeService.shared.validate(code: promoCodeInput)
        } catch {
            appliedPromoCode = nil
            promoCodeError = error.localizedDescription
        }
    }

    func removePromoCode() {
        appliedPromoCode = nil
        promoCodeInput = ""
        promoCodeError = nil
    }

    // MARK: - Phase 14 — Schedule for later

    @Published var showSchedulePicker = false
    @Published var scheduledDate: Date = Date().addingTimeInterval(3600)
    @Published private(set) var isScheduling = false

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
        case scheduledConfirmation(Date)   // Phase 14 — scheduleRide() succeeded
    }

    @Published private(set) var phase: BookingPhase = .idle
    @Published private(set) var activeRide: Ride?
    @Published private(set) var assignedDriver: AppUser?

    // Phase 9 — live driver location + ETA, shown on DriverAssignedRideView's map
    @Published private(set) var driverLocation: CLLocationCoordinate2D?
    @Published private(set) var etaMinutes: Double?

    // Phase 10 — surfaced on RideReceiptView if a wallet charge fails
    // after the ride is already marked complete (e.g. balance changed).
    @Published private(set) var walletChargeError: String?

    @Published var showCancelConfirmation = false

    private var observeTask: Task<Void, Never>?
    private var driverLocationTask: Task<Void, Never>?
    private let rideService = RideService.shared
    private let userService = UserService.shared
    private let directionsService = DirectionsService.shared
    private let walletService = WalletService.shared

    // Guards against double-notifying/double-charging if the snapshot
    // listener redelivers the same status (e.g. after a reconnect).
    private var lastNotifiedStatus: RideStatus?
    private var hasChargedWallet = false

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
                estimatedFare: discountedTotal,
                distanceKm: distanceKm,
                durationMin: durationMin,
                paymentMethod: selectedPaymentMethod,
                promoCode: appliedPromoCode?.id
            )
            phase = .searching
            observeRide(rideId: rideId)
            if let code = appliedPromoCode?.id {
                await PromoCodeService.shared.recordRedemption(code: code)
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Phase 14 — Schedule for later

    func scheduleRide() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            phase = .failed("You must be signed in to book a ride.")
            return
        }
        guard let pickupCoordinate, let dropoffCoordinate else {
            phase = .failed("Missing pickup or drop-off location.")
            return
        }
        guard scheduledDate > Date() else {
            phase = .failed("Pick a time in the future.")
            return
        }

        isScheduling = true
        defer { isScheduling = false }

        let pickup = RideLocation(address: pickupAddress, geoPoint: GeoPoint(
            latitude: pickupCoordinate.latitude, longitude: pickupCoordinate.longitude
        ))
        let dropoff = RideLocation(address: dropoffAddress, geoPoint: GeoPoint(
            latitude: dropoffCoordinate.latitude, longitude: dropoffCoordinate.longitude
        ))

        do {
            try await rideService.scheduleRide(
                riderId: uid,
                pickup: pickup,
                dropoff: dropoff,
                vehicleType: selectedVehicleType,
                estimatedFare: discountedTotal,
                distanceKm: distanceKm,
                durationMin: durationMin,
                paymentMethod: selectedPaymentMethod,
                scheduledFor: scheduledDate,
                promoCode: appliedPromoCode?.id
            )
            if let code = appliedPromoCode?.id {
                await PromoCodeService.shared.recordRedemption(code: code)
            }
            phase = .scheduledConfirmation(scheduledDate)
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
        notifyStatusChangeIfNeeded(ride)

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
            await chargeWalletIfNeeded(ride)
        case .cancelled:
            phase = .cancelled
            driverLocationTask?.cancel()
            driverLocationTask = nil
        case .scheduled:
            phase = .searching
        }
    }

    // MARK: - Phase 11 — local status notifications

    private func notifyStatusChangeIfNeeded(_ ride: Ride) {
        guard ride.status != lastNotifiedStatus else { return }
        lastNotifiedStatus = ride.status
        guard [.accepted, .ongoing, .completed, .cancelled].contains(ride.status) else { return }
        PushNotificationService.shared.notifyRideStatusChanged(
            rideId: ride.id ?? "",
            status: ride.status,
            forDriver: false
        )
    }

    // MARK: - Phase 10 — wallet charge on completion

    private func chargeWalletIfNeeded(_ ride: Ride) async {
        guard !hasChargedWallet else { return }
        guard ride.paymentMethod == .wallet else { return }
        guard let uid = Auth.auth().currentUser?.uid, let total = ride.fare?.total else { return }
        hasChargedWallet = true

        do {
            try await walletService.charge(uid: uid, amount: total)
        } catch {
            // Ride already happened — surface the problem on the receipt
            // rather than blocking anything; a real app would fall back
            // to prompting for another payment method here.
            walletChargeError = error.localizedDescription
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
