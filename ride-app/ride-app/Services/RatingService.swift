//
//  RatingService.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Writes a rating into the `ratings` subcollection under the ride it
//  belongs to (rides/{rideId}/ratings/{ratingId} — modeled since Phase 4
//  in Models/Rating.swift, already permitted by firestore.rules:
//  "allow create: if request.auth.uid == request.resource.data.fromUserId").
//
//  AVERAGING DESIGN NOTE — AppUser already carries `rating`/`ratingCount`
//  fields (Phase 4 groundwork), and the obvious way to keep them current
//  is a transaction that increments them on the *target* user's doc the
//  moment a rating is submitted. But firestore.rules' /users/{userId}
//  update rule only allows `request.auth.uid == userId` — a rider can
//  never write to a driver's own doc (nor should they be able to, or a
//  malicious client could set anyone's rating to whatever it wants). The
//  roadmap itself calls this out as needing "a Firestore transaction OR
//  Cloud Function" — without standing up Cloud Functions (same call
//  already made for WalletService/fare integrity in Phase 10's rules
//  comments), the only rule-safe write path is a *self* write. So instead
//  of the rater updating someone else's aggregate, the ratee recomputes
//  their OWN average the next time their own client is active — HomeView
//  calls `recomputeAndSaveOwnAverageRating` on appear for whichever user
//  is currently signed in, same pattern WalletService's header describes
//  for wallet balance. `fetchAverageRating` is separate and read-only, so
//  anyone can display a live number (e.g. the rider immediately after
//  submitting) without waiting on the ratee's own client to run.
//
//  Needs a Firestore index the first time fetchAverageRating runs —
//  Xcode's console prints a direct link to create it if missing
//  (collection group "ratings", field "toUserId", ascending).
//

import Foundation
import FirebaseFirestore

final class RatingService {

    static let shared = RatingService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Submit

    @discardableResult
    func submitRating(
        rideId: String,
        fromUserId: String,
        toUserId: String,
        value: Int,
        comment: String?
    ) async throws -> Rating {
        let rating = Rating(
            rideId: rideId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            value: value,
            comment: comment
        )
        let ref = db.collection(Constants.Firestore.ridesCollection)
            .document(rideId)
            .collection(Constants.Firestore.ratingsSubcollection)
            .document()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try ref.setData(from: rating) { error in
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

        return rating
    }

    /// Whether `fromUserId` has already rated this specific ride — used so
    /// RideDetailView doesn't offer "Rate Driver"/"Rate Rider" a second
    /// time if the user revisits a completed ride.
    func hasRated(rideId: String, fromUserId: String) async throws -> Bool {
        let snapshot = try await db.collection(Constants.Firestore.ridesCollection)
            .document(rideId)
            .collection(Constants.Firestore.ratingsSubcollection)
            .whereField("fromUserId", isEqualTo: fromUserId)
            .limit(to: 1)
            .getDocuments()
        return !snapshot.documents.isEmpty
    }

    // MARK: - Aggregate rating

    /// Live-computed average + count for any user — read-only, safe to
    /// call for someone other than the signed-in user.
    func fetchAverageRating(forUserId uid: String) async throws -> (average: Double, count: Int) {
        let snapshot = try await db.collectionGroup(Constants.Firestore.ratingsSubcollection)
            .whereField("toUserId", isEqualTo: uid)
            .getDocuments()
        let values = snapshot.documents.compactMap { $0["value"] as? Int }
        guard !values.isEmpty else { return (0, 0) }
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return (average, values.count)
    }

    /// Self-write only (see header) — call this for the *currently
    /// signed-in* user only, so AppUser.rating/ratingCount stays current
    /// on their own doc. Silently does nothing on failure/no ratings yet.
    func recomputeAndSaveOwnAverageRating(uid: String) async {
        guard let result = try? await fetchAverageRating(forUserId: uid), result.count > 0 else { return }
        try? await UserService.shared.updateProfileFields(uid: uid, fields: [
            "rating": result.average,
            "ratingCount": result.count
        ])
    }
}
