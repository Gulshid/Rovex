//
//  ProfileView.swift
//  RideBookingApp
//
//  Phase 3 — Read-only profile summary with a link into Edit Profile.
//  UPDATED in Phase 10 — added a wallet balance summary + practice-only
//  "add funds" action so the Payment Method screen's wallet path is
//  actually testable (see WalletService).
//

import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var router: Router
    @State private var isToppingUpWallet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoHeader
                    .padding(.top, 8)

                if let user = sessionManager.currentUser {
                    VStack(spacing: 0) {
                        infoRow(label: "Name", value: user.name)
                        Divider()
                        infoRow(label: "Email", value: user.email)
                        Divider()
                        infoRow(label: "Phone", value: (user.phone?.isEmpty == false) ? user.phone! : "Not set")
                        Divider()
                        infoRow(label: "Role", value: user.role == .driver ? "Driver" : "Rider")
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    if user.role == .driver, let vehicle = user.vehicle {
                        vehicleSummary(vehicle)
                    }

                    walletSummary(user)

                    Button("Edit Profile") {
                        router.push(.editProfile)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)

                    Button("Log Out", role: .destructive) {
                        sessionManager.signOut()
                    }
                    .padding(.top, 4)
                } else {
                    ProgressView()
                        .padding(.top, 40)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Profile")
    }

    private var photoHeader: some View {
        Group {
            if let urlString = sessionManager.currentUser?.photoURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholderAvatar
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
            } else {
                placeholderAvatar
            }
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .frame(width: 96, height: 96)
            .foregroundStyle(.secondary)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding()
    }

    private func vehicleSummary(_ vehicle: VehicleDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle").font(.headline)
            Text(vehicle.model.isEmpty ? "Not set" : "\(vehicle.color) \(vehicle.model)")
                .foregroundStyle(.secondary)
            Text("Plate: \(vehicle.plateNumber.isEmpty ? "Not set" : vehicle.plateNumber)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Phase 10 — Wallet
    //
    // Practice-only balance display + "add funds" action (see
    // WalletService.topUp) — there's no real payment gateway, so this is
    // just the simplest way to test the Payment Method screen's wallet
    // path end-to-end.

    private func walletSummary(_ user: AppUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Wallet").font(.headline)
                Spacer()
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", user.walletBalance ?? 0))")
                    .font(.headline)
            }

            Button {
                Task {
                    isToppingUpWallet = true
                    defer { isToppingUpWallet = false }
                    if let uid = user.id {
                        try? await WalletService.shared.topUp(uid: uid, amount: 20)
                        await sessionManager.refreshCurrentUser()
                    }
                }
            } label: {
                HStack {
                    if isToppingUpWallet {
                        ProgressView()
                    }
                    Text("Add \(Constants.Fare.currencySymbol)20.00 (test)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isToppingUpWallet)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(SessionManager())
        .environmentObject(Router())
}
