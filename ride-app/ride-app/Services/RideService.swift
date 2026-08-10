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

import Foundation
import FirebaseFirestore

enum RideServiceError: LocalizedError {
    case notFound
    case missingId

    var errorDescription: String? {
        switch self {
        case .notFound: return "That ride could not be found."
        case .missingId: return "Ride is missing an id."
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

    /// Creates a new ride with status "requested" and returns its id.
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

        let docRef = try ridesCollection.addDocument(from: ride)
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
}
