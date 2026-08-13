//
//  Message.swift
//  RideBookingApp
//
//  Phase 13 — Chat / In-App Communication
//  Matches the `messages` subcollection under each ride doc:
//  rides/{rideId}/messages/{messageId}
//

import Foundation
import FirebaseFirestore

struct Message: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    @ServerTimestamp var timestamp: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id
        case senderId
        case text
        case timestamp
    }
}
