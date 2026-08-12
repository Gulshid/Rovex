//
//  PaymentMethodView.swift
//  RideBookingApp
//
//  Phase 10 — Fare Calculation & Mock Payments
//
//  Presented as a sheet from BookRideView before "Confirm Ride". Lets the
//  rider pick Cash / Card (mock) / Wallet, shows the live wallet balance,
//  and offers a practice-only "Add funds" action so the wallet path is
//  actually testable without a real payment gateway.
//

import SwiftUI

struct PaymentMethodView: View {

    @StateObject private var viewModel: PaymentMethodViewModel
    @Environment(\.dismiss) private var dismiss

    /// Called with the chosen method when the rider taps "Done".
    let onSelect: (PaymentMethod) -> Void

    init(selected: PaymentMethod, fareTotal: Double, onSelect: @escaping (PaymentMethod) -> Void) {
        _viewModel = StateObject(wrappedValue: PaymentMethodViewModel(selected: selected, fareTotal: fareTotal))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PaymentMethod.allCases) { method in
                        methodRow(method)
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.selected = method }
                    }
                } footer: {
                    Text("This is a practice project — Card is simulated and Cash is just recorded for the receipt. No real money moves.")
                }

                if viewModel.selected == .wallet {
                    Section("Wallet") {
                        HStack {
                            Text("Balance")
                            Spacer()
                            if let balance = viewModel.walletBalance {
                                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", balance))")
                                    .foregroundStyle(viewModel.walletCoversFare ? .primary : .red)
                            } else {
                                ProgressView()
                            }
                        }

                        if let balance = viewModel.walletBalance, !viewModel.walletCoversFare {
                            Text("Not enough to cover the \(Constants.Fare.currencySymbol)\(String(format: "%.2f", viewModel.fareTotal)) fare. Add funds below or choose another method.")
                                .font(.footnote)
                                .foregroundStyle(.red)
                            _ = balance
                        }

                        Button {
                            Task { await viewModel.topUp(20) }
                        } label: {
                            HStack {
                                if viewModel.isToppingUp {
                                    ProgressView()
                                }
                                Text("Add \(Constants.Fare.currencySymbol)20.00 (test)")
                            }
                        }
                        .disabled(viewModel.isToppingUp)
                    }
                }
            }
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSelect(viewModel.selected)
                        dismiss()
                    }
                    .disabled(viewModel.selected == .wallet && !viewModel.walletCoversFare)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await viewModel.loadWalletBalance() }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private func methodRow(_ method: PaymentMethod) -> some View {
        HStack(spacing: 14) {
            Image(systemName: method.iconName)
                .font(.title3)
                .frame(width: 32)
                .foregroundStyle(viewModel.selected == method ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(method.displayName)
                    .font(.body.weight(.semibold))
                Text(method.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.selected == method {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PaymentMethodView(selected: .cash, fareTotal: 12.5) { _ in }
}
