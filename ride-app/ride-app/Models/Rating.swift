//
//  Rating.swift
//  RideBookingApp
//
//  Phase 4 - Firestore Data Modeling
//  Matches the `ratings` subcollection under each ride doc:
//  rides/{rideId}/ratings/{ratingId}
//

import Foundation
import FirebaseFirestore

struct Rating: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var rideId: String
    var fromUserId: String
    var toUserId: String
    var value: Int              // 1...5
    var comment: String?
    @ServerTimestamp var createdAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case rideId
        case fromUserId
        case toUserId
        case value
        case comment
        case createdAt
    }
}
