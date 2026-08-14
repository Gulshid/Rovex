//
//  PromoCodeService.swift
//  RideBookingApp
//
//  Phase 14 — Advanced Features (Promo Codes)
//
//  Validates a code against the `promoCodes` collection at checkout and
//  (best-effort) bumps its redemption counter once a ride using it
//  actually completes. Codes are looked up by document ID directly
//  (uppercased) rather than a query — cheaper and avoids needing an
//  index for something this simple.
//
//  NOTE on redemptionCount races: incrementing with FieldValue.increment
//  is atomic at the Firestore level, so two riders redeeming the same
//  code at once can't corrupt the counter — but it does mean
//  `maxRedemptions` can be very slightly oversold under heavy concurrent
//  load (a check-then-increment gap), which is an acceptable tradeoff for
//  a practice app's promo codes rather than a real inventory system.
//

import Foundation
import FirebaseFirestore

enum PromoCodeError: LocalizedError {
    case notFound
    case notRedeemable

    var errorDescription: String? {
        switch self {
        case .notFound: return "That promo code doesn't exist."
        case .notRedeemable: return "That promo code has expired or is no longer available."
        }
    }
}

final class PromoCodeService {

    static let shared = PromoCodeService()
    private let db = Firestore.firestore()

    private init() {}

    private var collection: CollectionReference {
        db.collection(Constants.Firestore.promoCodesCollection)
    }

    /// Looks up a code and returns it only if currently redeemable.
    /// Throws `.notFound` or `.notRedeemable` otherwise so the caller can
    /// show a clear message rather than a generic Firestore error.
    func validate(code: String) async throws -> PromoCode {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw PromoCodeError.notFound }

        let snapshot = try await collection.document(normalized).getDocument()
        guard snapshot.exists else { throw PromoCodeError.notFound }

        let promo = try snapshot.data(as: PromoCode.self)
        guard promo.isRedeemable else { throw PromoCodeError.notRedeemable }
        return promo
    }

    /// Best-effort — called once a ride that used a promo code completes.
    /// Failure here shouldn't block the ride's own completion flow.
    func recordRedemption(code: String) async {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        try? await collection.document(normalized).updateData([
            "redemptionCount": FieldValue.increment(Int64(1))
        ])
    }
}
