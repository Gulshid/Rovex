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
        estimatedFare: Double
    ) async throws -> String {
        let ride = Ride(
            riderId: riderId,
            driverId: nil,
            pickupLocation: pickup,
            dropoffLocation: dropoff,
            status: .requested,
            vehicleType: vehicleType,
            estimatedFare: estimatedFare
        )

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

    func completeRide(rideId: String) async throws {
        try await ridesCollection.document(rideId).updateData([
            "status": RideStatus.completed.rawValue,
            "completedAt": FieldValue.serverTimestamp()
        ])
    }
}
