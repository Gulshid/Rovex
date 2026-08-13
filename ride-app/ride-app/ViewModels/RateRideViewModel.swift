//
//  RateRideViewModel.swift
//  RideBookingApp
//
//  Phase 12 — Ratings, Reviews & Ride History
//
//  Drives RateRideView — a star rating + optional comment submitted
//  against a specific completed ride. `isDriver` describes the
//  *currently signed-in* user's role (true = a driver rating their
//  rider), used only to pick the right copy ("How was your rider?" vs
//  "How was your driver?").
//

import Foundation
import FirebaseAuth

@MainActor
final class RateRideViewModel: ObservableObject {

    let rideId: String
    let ratedUserId: String
    let isDriver: Bool

    @Published var value: Int = 5
    @Published var comment: String = ""
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var didSubmit = false

    private let ratingService = RatingService.shared

    init(rideId: String, ratedUserId: String, isDriver: Bool) {
        self.rideId = rideId
        self.ratedUserId = ratedUserId
        self.isDriver = isDriver
    }

    func submit() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
            try await ratingService.submitRating(
                rideId: rideId,
                fromUserId: uid,
                toUserId: ratedUserId,
                value: value,
                comment: trimmedComment.isEmpty ? nil : trimmedComment
            )
            didSubmit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
