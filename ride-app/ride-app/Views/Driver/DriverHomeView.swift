//
//  DriverHomeView.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//
//  Replaces the "Driver request matching arrives in Phase 8" placeholder
//  that used to sit on HomeView. A driver toggles Online/Offline here;
//  while online, an incoming ride request slides up as a card (with a
//  countdown) whenever one is nearby. Accepting navigates to
//  ActiveDriverRideView.
//

import SwiftUI

struct DriverHomeView: View {

    @StateObject private var viewModel = DriverHomeViewModel()
    @EnvironmentObject private var router: Router

    var body: some View {
        ZStack(alignment: .bottom) {
            content

            if let ride = viewModel.incomingRide {
                IncomingRideRequestCard(
                    ride: ride,
                    countdownRemaining: viewModel.countdownRemaining,
                    totalSeconds: Constants.Matching.requestTimeoutSeconds,
                    onAccept: {
                        Task {
                            if let rideId = await viewModel.acceptRequest() {
                                router.push(.activeDriverRide(rideId: rideId))
                            }
                        }
                    },
                    onReject: {
                        viewModel.rejectRequest()
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Driver")
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.incomingRide?.id)
        .onAppear { viewModel.onAppear() }
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

    private var content: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(viewModel.isOnline ? Color.green.opacity(0.15) : Color(.secondarySystemBackground))
                    .frame(width: 160, height: 160)

                Image(systemName: "car.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(viewModel.isOnline ? .green : .secondary)
            }

            Text(viewModel.isOnline ? "You're online" : "You're offline")
                .font(.title2.bold())

            Text(viewModel.isOnline
                 ? "Listening for nearby ride requests…"
                 : "Go online to start receiving ride requests.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                viewModel.toggleOnline()
            } label: {
                HStack {
                    if viewModel.isTogglingOnline {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isOnline ? "Go Offline" : "Go Online")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isOnline ? .red : .green)
            .controlSize(.large)
            .disabled(viewModel.isTogglingOnline)
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    NavigationStack {
        DriverHomeView()
            .environmentObject(Router())
    }
}
