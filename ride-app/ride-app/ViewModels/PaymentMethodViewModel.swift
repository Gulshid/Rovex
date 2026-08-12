//
//  PaymentMethodViewModel.swift
//  RideBookingApp
//
//  Phase 10 — Fare Calculation & Mock Payments
//
//  Backs PaymentMethodView, presented as a sheet from BookRideView before
//  the rider confirms. Shows the live wallet balance (so a rider picking
//  "Wallet" can see up front whether it covers the fare) and lets them
//  top up for testing since there's no real gateway.
//

import Foundation
import FirebaseAuth

@MainActor
final class PaymentMethodViewModel: ObservableObject {

    @Published var selected: PaymentMethod
    @Published private(set) var walletBalance: Double?
    @Published var isToppingUp = false
    @Published var errorMessage: String?

    let fareTotal: Double

    private let userService = UserService.shared
    private let walletService = WalletService.shared

    init(selected: PaymentMethod, fareTotal: Double) {
        self.selected = selected
        self.fareTotal = fareTotal
    }

    var walletCoversFare: Bool {
        guard let walletBalance else { return false }
        return walletBalance >= fareTotal
    }

    func loadWalletBalance() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if let user = try? await userService.fetchUser(uid: uid) {
            walletBalance = user.walletBalance ?? 0
        }
    }

    /// Practice-only "top up" so you can actually test the wallet flow
    /// without a real payment gateway — see WalletService.topUp.
    func topUp(_ amount: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isToppingUp = true
        defer { isToppingUp = false }
        do {
            try await walletService.topUp(uid: uid, amount: amount)
            await loadWalletBalance()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
