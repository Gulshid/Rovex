//
//  PromoCode.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (Promo Codes)
//  Matches the `promoCodes` collection (Constants.Firestore.promoCodesCollection,
//  already reserved since Phase 1). Document ID IS the code itself
//  (uppercased, e.g. "WELCOME10") so lookups are a single getDocument
//  rather than a query.
//

import Foundation
import FirebaseFirestore

enum PromoCodeDiscountType: String, Codable {
    case percentage   // value is 0...100
    case flatAmount   // value is a currency amount
}

struct PromoCode: Codable, Identifiable, Equatable {
    @DocumentID var id: String?   // the code itself, e.g. "WELCOME10"
    var discountType: PromoCodeDiscountType
    var value: Double
    var isActive: Bool
    var maxRedemptions: Int?
    var redemptionCount: Int
    var expiresAt: Timestamp?

    enum CodingKeys: String, CodingKey {
        case id, discountType, value, isActive, maxRedemptions, redemptionCount, expiresAt
    }

    /// Discount amount for a given fare total, clamped so it never makes
    /// the ride free or negative.
    func discountAmount(onTotal total: Double) -> Double {
        let raw: Double
        switch discountType {
        case .percentage:
            raw = total * (value / 100)
        case .flatAmount:
            raw = value
        }
        return min(max(raw, 0), total)
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt.dateValue() < Date()
    }

    var isRedeemable: Bool {
        guard isActive, !isExpired else { return false }
        if let max = maxRedemptions { return redemptionCount < max }
        return true
    }
}
