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
//  FIXED — Xcode reported "The compiler is unable to type-check this
//  expression in reasonable time" on `body`. That's not a real bug, it's
//  the type-checker giving up: the original `body` was one giant `List`
//  containing nested `Section`s, `if let`/`if` conditionals, string
//  interpolations, and a multi-item `.toolbar` closure, all inferred as a
//  single expression. Splitting it into small computed properties/
//  functions with an explicit `some View` (or `some ToolbarContent`)
//  return type each lets Swift solve each piece independently instead of
//  the whole tree at once — same UI, just restructured so it compiles.
//
//  FIXED (2) — that split then surfaced a real type error that had been
//  hiding inside the giant expression: `.foregroundStyle(condition ?
//  .primary : .red)` doesn't type-check because `.primary` infers as
//  `HierarchicalShapeStyle.primary` while `.red` infers as `Color.red` —
//  different types, and a ternary requires both branches to match.
//  Spelling both out as `Color.primary` / `Color.red` fixes it.
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
                methodsSection
                if viewModel.selected == .wallet {
                    walletSection
                }
            }
            .navigationTitle("Payment Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await viewModel.loadWalletBalance() }
            .alert(
                "Something went wrong",
                isPresented: errorAlertBinding
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Sections

    private var methodsSection: some View {
        Section {
            ForEach(PaymentMethod.allCases) { method in
                methodRow(method)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.selected = method }
            }
        } footer: {
            Text("This is a practice project — Card is simulated and Cash is just recorded for the receipt. No real money moves.")
        }
    }

    private var walletSection: some View {
        Section("Wallet") {
            walletBalanceRow
            if viewModel.walletBalance != nil && !viewModel.walletCoversFare {
                insufficientFundsMessage
            }
            topUpButton
        }
    }

    // MARK: - Wallet section pieces

    private var walletBalanceRow: some View {
        HStack {
            Text("Balance")
            Spacer()
            if let balance = viewModel.walletBalance {
                Text(formattedAmount(balance))
                    .foregroundStyle(viewModel.walletCoversFare ? Color.primary : Color.red)
            } else {
                ProgressView()
            }
        }
    }

    private var insufficientFundsMessage: some View {
        Text("Not enough to cover the \(formattedAmount(viewModel.fareTotal)) fare. Add funds below or choose another method.")
            .font(.footnote)
            .foregroundStyle(.red)
    }

    private var topUpButton: some View {
        Button {
            Task { await viewModel.topUp(20) }
        } label: {
            topUpButtonLabel
        }
        .disabled(viewModel.isToppingUp)
    }

    private var topUpButtonLabel: some View {
        HStack {
            if viewModel.isToppingUp {
                ProgressView()
            }
            Text("Add \(formattedAmount(20)) (test)")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    // MARK: - Row

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

    // MARK: - Helpers

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func formattedAmount(_ value: Double) -> String {
        "\(Constants.Fare.currencySymbol)\(String(format: "%.2f", value))"
    }
}

#Preview {
    PaymentMethodView(selected: .cash, fareTotal: 12.5) { _ in }
}
