//
//  User.swift
//  RideBookingApp
//
//  Phase 4 - Firestore Data Modeling
//  Matches the `users` collection.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

enum UserRole: String, Codable {
    case rider
    case driver
}

struct User: Codable, Identifiable, Equatable {
    @DocumentID var id: String?          // Firestore doc id == Firebase Auth uid
    var name: String
    var email: String
    var phone: String?
    var role: UserRole
    var photoURL: String?                // set by Cloudinary upload (Phase 5)
    @ServerTimestamp var createdAt: Timestamp?

    // Optional convenience fields used later in the roadmap
    var homeAddress: String?             // Phase 14 - favorite locations
    var workAddress: String?             // Phase 14 - favorite locations
    var walletBalance: Double?           // Phase 10 - optional in-app wallet
    var fcmToken: String?                // Phase 11 - push notifications

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case role
        case photoURL
        case createdAt
        case homeAddress
        case workAddress
        case walletBalance
        case fcmToken
    }
}
