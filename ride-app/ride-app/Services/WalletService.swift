//
//  WalletService.swift
//  RideBookingApp
//
//  Phase 10 — Fare Calculation & Mock Payments
//
//  Backs the optional in-app wallet: a `walletBalance` Double already
//  lives on AppUser (Models/User.swift, Phase 4 groundwork). There's no
//  real payment gateway in this practice app, so "topping up" just adds
//  a number to your own document — the point is to practice a Firestore
//  transaction that reads-then-writes safely.
//
//  IMPORTANT — who is allowed to call `charge`:
//  firestore.rules only lets a user update their OWN /users/{uid} doc
//  (`request.auth.uid == userId`). A driver can never write to the
//  rider's wallet balance directly. So `charge` must always be called
//  from the RIDER'S OWN device/session — see BookRideViewModel, which
//  calls this exactly once, right when it observes its own ride flip to
//  `.completed` with paymentMethod == .wallet. The driver-side
//  RideService.completeRide only ever writes the `rides` doc (which the
//  security rules do allow the assigned driver to update).
//

import Foundation
import FirebaseFirestore

enum WalletServiceError: LocalizedError {
    case insufficientFunds(shortfall: Double)
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .insufficientFunds(let shortfall):
            return "Wallet balance is too low by \(Constants.Fare.currencySymbol)\(String(format: "%.2f", shortfall))."
        case .userNotFound:
            return "Couldn't find your account."
        }
    }
}

final class WalletService {

    static let shared = WalletService()
    private let db = Firestore.firestore()

    private init() {}

    private func userRef(_ uid: String) -> DocumentReference {
        db.collection(Constants.Firestore.usersCollection).document(uid)
    }

    /// Deducts `amount` from the given user's wallet inside a transaction
    /// (read current balance, verify it covers the charge, write the new
    /// balance) so two concurrent charges can never overdraw the wallet.
    /// Throws `.insufficientFunds` without writing anything if the balance
    /// is too low.
    func charge(uid: String, amount: Double) async throws {
        let ref = userRef(uid)

        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }

            let currentBalance = snapshot.get("walletBalance") as? Double ?? 0

            guard currentBalance >= amount else {
                errorPointer?.pointee = NSError(
                    domain: "WalletService",
                    code: 402,
                    userInfo: [NSLocalizedDescriptionKey:
                        WalletServiceError.insufficientFunds(shortfall: amount - currentBalance).errorDescription ?? ""]
                )
                return nil
            }

            let newBalance = ((currentBalance - amount) * 100).rounded() / 100
            transaction.updateData(["walletBalance": newBalance], forDocument: ref)
            return nil
        }
    }

    /// Practice-app stand-in for a real top-up flow (Stripe/PayPal sandbox
    /// etc — see the roadmap's optional Phase 10 note). Just adds funds
    /// directly since there's no gateway to call.
    func topUp(uid: String, amount: Double) async throws {
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(self.userRef(uid))
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let currentBalance = snapshot.get("walletBalance") as? Double ?? 0
            let newBalance = ((currentBalance + amount) * 100).rounded() / 100
            transaction.updateData(["walletBalance": newBalance], forDocument: self.userRef(uid))
            return nil
        }
    }
}
