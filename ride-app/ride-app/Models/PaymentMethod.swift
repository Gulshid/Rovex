//
//  PaymentMethod.swift
//  RideBookingApp
//
//  Phase 10 — Fare Calculation & Mock Payments
//
//  A rider picks one of these on the Payment Method screen before
//  confirming a ride. No real payment gateway is wired up (this is a
//  practice project) — "card" is a mock/simulated charge, "wallet" draws
//  down the in-app walletBalance field on the user's own Firestore doc
//  (see WalletService), and "cash" is just recorded for the receipt.
//

import Foundation

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case card
    case wallet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .card: return "Card (mock)"
        case .wallet: return "Wallet"
        }
    }

    var subtitle: String {
        switch self {
        case .cash: return "Pay your driver directly"
        case .card: return "Simulated charge — no real gateway"
        case .wallet: return "Deducted from your in-app balance"
        }
    }

    var iconName: String {
        switch self {
        case .cash: return "banknote.fill"
        case .card: return "creditcard.fill"
        case .wallet: return "wallet.pass.fill"
        }
    }
}
