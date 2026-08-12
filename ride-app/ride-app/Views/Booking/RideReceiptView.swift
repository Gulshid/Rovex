//
//  RideReceiptView.swift
//  RideBookingApp
//
//  Phase 10 — Fare Calculation & Mock Payments
//
//  Shown on the Rider side once BookRideViewModel.phase == .completed.
//  Reads the `fare` (FareBreakdown) that RideService.completeRide wrote
//  onto the ride document — a real base + distance + time breakdown, not
//  just the single estimatedFare total shown on the booking screen.
//

import SwiftUI

struct RideReceiptView: View {

    let ride: Ride?
    /// Set when a wallet charge was attempted and failed (e.g. balance
    /// dropped between confirming and completion). nil means either no
    /// charge was needed or it succeeded.
    let walletChargeError: String?
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Ride completed")
                        .font(.title2.bold())
                }
                .padding(.top, 24)

                if let fare = ride?.fare {
                    receiptCard(fare)
                } else {
                    ProgressView("Finalizing receipt…")
                        .padding(.top, 20)
                }

                if let walletChargeError {
                    Label(walletChargeError, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }

                Button("Back to Home", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
            .padding()
        }
    }

    private func receiptCard(_ fare: FareBreakdown) -> some View {
        VStack(spacing: 0) {
            row(label: "Base fare", value: fare.baseFare)
            Divider()
            row(label: "Distance (\(String(format: "%.1f", fare.distanceKm)) km)", value: fare.distanceFare)
            Divider()
            row(label: "Time (\(String(format: "%.0f", fare.durationMin)) min)", value: fare.timeFare)
            Divider()
            HStack {
                Text("Total").font(.body.weight(.semibold))
                Spacer()
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", fare.total))")
                    .font(.body.weight(.semibold))
            }
            .padding()
            Divider()
            HStack {
                Text("Paid with").foregroundStyle(.secondary)
                Spacer()
                Text(PaymentMethod(rawValue: fare.paymentMethod)?.displayName ?? fare.paymentMethod.capitalized)
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func row(label: String, value: Double) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", value))")
        }
        .padding()
    }
}

#Preview {
    RideReceiptView(
        ride: nil,
        walletChargeError: nil,
        onDone: {}
    )
}
