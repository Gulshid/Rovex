//
//  RideService.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Creates the `rides` document when a rider confirms a booking, and
//  exposes a live AsyncStream of updates via a Firestore snapshot
//  listener so BookRideViewModel can react as status changes
//  (requested → accepted → ongoing → completed/cancelled).
//
//  Phase 8 (driver accept/reject) and Phase 9 (live tracking) will read
//  and write the same `rides` collection through this same service.
//
//  UPDATED in Phase 8 — added `observeRequestedRides` (feeds DriverService's
//  nearby-matching filter) and `acceptRide` (a Firestore transaction so two
//  drivers can never win the same ride), plus `startRide`/`completeRide`
//  for progressing an accepted ride.
//
//  FIXED — requestRide() previously used addDocument(from:), which encodes
//  and generates a local document ID synchronously but does NOT wait for
//  the write to be committed on the server — it's fire-and-forget. The
//  caller (BookRideViewModel.confirmRide) immediately attached a listener
//  to that same rideId, and if the Listen reached the backend before the
//  Create was actually applied, the security rules' read check evaluated
//  against a non-existent document and threw "Missing or insufficient
//  permissions". requestRide now builds the DocumentReference up front and
//  awaits setData(from:) via a checked continuation, so the returned id is
//  guaranteed to correspond to a document that has actually been written
//  before any caller starts listening to it. (Also fixed defense-in-depth
//  on the rules side — see firestore.rules — but this closes the race at
//  its source instead of only papering over it.)
//
//  UPDATED in Phase 10 — requestRide now also stores `distanceKm`/
//  `durationMin` (so the final receipt can be recomputed with the exact
//  same trip numbers the rider was quoted) and the rider's chosen
//  `paymentMethod`. completeRide now computes a real FareBreakdown with
//  FareEstimator and writes it onto `fare` instead of only flipping
//  status — that receipt is what RideReceiptView and the driver's
//  completion screen both read.
//
//  UPDATED in Phase 12 — added `fetchRideHistoryPage`, a cursor-paginated
//  query (order by createdAt desc, startAfterDocument) feeding
//  RideHistoryViewModel. Riders and drivers both call the same method
//  with a different `field` ("riderId" vs "driverId") since both are
//  just equality-filtered reads over the same `rides` collection.
//
//  UPDATED in Phase 14 — added `scheduleRide` (writes status "scheduled"
//  instead of "requested", so DriverService's matching query — which
//  only ever looks at "requested" — leaves it alone until its time
//  comes), `fetchScheduledRides`, `cancelScheduledRide`, and
//  `activateDueScheduledRides`. There's no Cloud Functions/cron backend
//  in this practice app, so activation runs client-side — HomeView calls
//  it on appear for the signed-in rider, same self-triggered pattern
//  already used for WalletService/RatingService elsewhere in this
//  codebase. `requestRide` also gained an optional `promoCode` param so
//  the code actually gets stored on the ride it was used for.
//
//  A NOTE ON INDEXES — the first time each of these runs (once for
//  riderId+createdAt, once for driverId+createdAt), Firestore will reject
//  the query with an error that includes a direct link to create the
//  needed composite index in the Firebase console. Click it once per
//  field and the query works from then on — this is normal and expected
//  the first time a new query shape runs against a non-trivial collection.
//

import Foundation
import FirebaseFirestore

enum RideServiceError: LocalizedError {
    case notFound
    case missingId
    case alreadyTaken

    var errorDescription: String? {
        switch self {
        case .notFound: return "That ride could not be found."
        case .missingId: return "Ride is missing an id."
        case .alreadyTaken: return "Sorry, another driver already accepted this ride."
        }
    }
}

final class RideService {

    static let shared = RideService()
    private let db = Firestore.firestore()

    private init() {}

    private var ridesCollection: CollectionReference {
        db.collection(Constants.Firestore.ridesCollection)
    }

    // MARK: - Create

    /// Creates a new ride with status "requested" and returns its id, only
    /// once the write has actually been confirmed by the server — so it's
    /// safe for the caller to immediately attach a listener to that id.
    @discardableResult
    func requestRide(
        riderId: String,
        pickup: RideLocation,
        dropoff: RideLocation,
        vehicleType: VehicleType,
        estimatedFare: Double,
        distanceKm: Double,
        durationMin: Double,
        paymentMethod: PaymentMethod,
        promoCode: String? = nil
    ) async throws -> String {
        var ride = Ride(
            riderId: riderId,
            driverId: nil,
            pickupLocation: pickup,
            dropoffLocation: dropoff,
            status: .requested,
            vehicleType: vehicleType,
            estimatedFare: estimatedFare,
            distanceKm: distanceKm,
            durationMin: durationMin,
            paymentMethod: paymentMethod
        )
        ride.promoCode = promoCode

        // Pre-generate the document reference locally (this part is always
        // synchronous/local — it's the write itself we now wait on).
        let docRef = ridesCollection.document()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try docRef.setData(from: ride) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }

        return docRef.documentID
    }

    // MARK: - Live updates

    /// Streams live updates for a single ride document. The stream finishes
    /// when the caller cancels the enclosing Task (e.g. view disappears).
    func observeRide(rideId: String) -> AsyncThrowingStream<Ride, Error> {
        AsyncThrowingStream { continuation in
            let listener = ridesCollection.document(rideId)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot, snapshot.exists else {
                        continuation.finish(throwing: RideServiceError.notFound)
                        return
                    }
                    do {
                        let ride = try snapshot.data(as: Ride.self)
                        continuation.yield(ride)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    // MARK: - Rider actions

    func cancelRide(rideId: String) async throws {
        try await ridesCollection.document(rideId).updateData([
            "status": RideStatus.cancelled.rawValue,
            "cancelledAt": FieldValue.serverTimestamp()
        ])
    }

    func fetchRide(rideId: String) async throws -> Ride {
        let snapshot = try await ridesCollection.document(rideId).getDocument()
        guard snapshot.exists else { throw RideServiceError.notFound }
        return try snapshot.data(as: Ride.self)
    }

    // MARK: - Phase 8 — Driver matching & actions

    /// Live stream of every ride currently in "requested" status.
    /// DriverService filters/sorts this client-side by distance — see
    /// DriverService.nearbyRequestedRides.
    func observeRequestedRides() -> AsyncThrowingStream<[Ride], Error> {
        AsyncThrowingStream { continuation in
            let listener = ridesCollection
                .whereField("status", isEqualTo: RideStatus.requested.rawValue)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }
                    let rides = snapshot.documents.compactMap { try? $0.data(as: Ride.self) }
                    continuation.yield(rides)
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    /// Assigns a driver to a ride inside a Firestore transaction, so two
    /// drivers racing to accept the same request can never both win —
    /// whoever's transaction commits first "requested" status wins; the
    /// second throws `.alreadyTaken`.
    func acceptRide(rideId: String, driverId: String) async throws {
        let rideRef = ridesCollection.document(rideId)

        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(rideRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            guard snapshot.get("status") as? String == RideStatus.requested.rawValue else {
                errorPointer?.pointee = NSError(
                    domain: "RideService",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: RideServiceError.alreadyTaken.errorDescription ?? ""]
                )
                return nil
            }

            transaction.updateData([
                "driverId": driverId,
                "status": RideStatus.accepted.rawValue,
                "acceptedAt": FieldValue.serverTimestamp()
            ], forDocument: rideRef)

            return nil
        }
    }

    func startRide(rideId: String) async throws {
        try await ridesCollection.document(rideId).updateData([
            "status": RideStatus.ongoing.rawValue,
            "startedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Marks a ride completed and writes the final `fare` receipt.
    ///
    /// Phase 10 — recomputes the fare with FareEstimator using the same
    /// distance/duration captured at booking time (so the receipt matches
    /// what the rider was quoted rather than drifting), tagged with
    /// whichever `paymentMethod` the rider picked on the Payment Method
    /// screen. Returns the finalized Ride so the caller (driver-side
    /// ActiveDriverRideViewModel) can show the payout on its own
    /// completion screen without a second round-trip read.
    @discardableResult
    func completeRide(rideId: String) async throws -> Ride {
        let ride = try await fetchRide(rideId: rideId)

        let distanceKm = ride.distanceKm ?? 0
        let durationMin = ride.durationMin ?? 0
        let estimate = FareEstimator.estimate(
            distanceKm: distanceKm,
            durationMin: durationMin,
            vehicleType: ride.vehicleType
        )

        let fareData: [String: Any] = [
            "baseFare": estimate.baseFare,
            "distanceFare": estimate.distanceFare,
            "timeFare": estimate.timeFare,
            "total": estimate.total,
            "distanceKm": distanceKm,
            "durationMin": durationMin,
            "paymentMethod": ride.paymentMethod.rawValue
        ]

        try await ridesCollection.document(rideId).updateData([
            "status": RideStatus.completed.rawValue,
            "completedAt": FieldValue.serverTimestamp(),
            "fare": fareData
        ])

        return try await fetchRide(rideId: rideId)
    }

    // MARK: - Phase 12 — Ride history (paginated)

    /// One page of a user's past rides, newest first. Pass `field` as
    /// `"riderId"` for a rider's history or `"driverId"` for a driver's —
    /// both are just equality-filtered, createdAt-descending reads over
    /// the same collection. Pass the last document from the previous page
    /// as `after` to fetch the next one (Firestore cursor pagination).
    func fetchRideHistoryPage(
        forUserId uid: String,
        field: String,
        pageSize: Int = 20,
        after lastDocument: DocumentSnapshot? = nil
    ) async throws -> (rides: [Ride], lastDocument: DocumentSnapshot?) {
        var query: Query = ridesCollection
            .whereField(field, isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        let snapshot = try await query.getDocuments()
        let rides = snapshot.documents.compactMap { try? $0.data(as: Ride.self) }
        return (rides, snapshot.documents.last)
    }

    // MARK: - Phase 14 — Scheduled rides

    /// Creates a ride with status "scheduled" rather than "requested" —
    /// see this file's header for why that keeps it invisible to driver
    /// matching until `activateDueScheduledRides` flips it over.
    @discardableResult
    func scheduleRide(
        riderId: String,
        pickup: RideLocation,
        dropoff: RideLocation,
        vehicleType: VehicleType,
        estimatedFare: Double,
        distanceKm: Double,
        durationMin: Double,
        paymentMethod: PaymentMethod,
        scheduledFor: Date,
        promoCode: String?
    ) async throws -> String {
        var ride = Ride(
            riderId: riderId,
            driverId: nil,
            pickupLocation: pickup,
            dropoffLocation: dropoff,
            status: .scheduled,
            vehicleType: vehicleType,
            estimatedFare: estimatedFare,
            distanceKm: distanceKm,
            durationMin: durationMin,
            paymentMethod: paymentMethod
        )
        ride.scheduledFor = Timestamp(date: scheduledFor)
        ride.promoCode = promoCode

        let docRef = ridesCollection.document()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try docRef.setData(from: ride) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        return docRef.documentID
    }

    /// A rider's upcoming scheduled rides, soonest first. Needs a
    /// composite index (riderId + status + scheduledFor) — same one-time
    /// setup as the Phase 12 history queries; Xcode's console prints a
    /// direct link the first time this runs.
    func fetchScheduledRides(forRiderId uid: String) async throws -> [Ride] {
        let snapshot = try await ridesCollection
            .whereField("riderId", isEqualTo: uid)
            .whereField("status", isEqualTo: RideStatus.scheduled.rawValue)
            .order(by: "scheduledFor")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Ride.self) }
    }

    func cancelScheduledRide(rideId: String) async throws {
        try await ridesCollection.document(rideId).updateData([
            "status": RideStatus.cancelled.rawValue,
            "cancelledAt": FieldValue.serverTimestamp()
        ])
    }

    /// Flips any of this rider's scheduled rides whose time has arrived
    /// over to "requested" so DriverService's matching query picks them
    /// up. Best-effort and silent on failure — called opportunistically
    /// from HomeView.onAppear, not on any guaranteed schedule, since
    /// there's no server-side cron in this practice app.
    func activateDueScheduledRides(forRiderId uid: String) async {
        guard let scheduled = try? await fetchScheduledRides(forRiderId: uid) else { return }
        let due = scheduled.filter { ride in
            guard let scheduledFor = ride.scheduledFor?.dateValue() else { return false }
            return scheduledFor <= Date()
        }
        for ride in due {
            guard let id = ride.id else { continue }
            try? await ridesCollection.document(id).updateData([
                "status": RideStatus.requested.rawValue
            ])
        }
    }
}
