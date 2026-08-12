//
//  ActiveDriverRideView.swift
//  RideBookingApp
//
//  Phase 8 — Driver Mode: Requests, Accept/Reject, Matching
//  Phase 9 — Real-Time Ride Tracking (Live Location)
//
//  Shown right after a driver accepts a request. Walks through:
//   accepted → "Start Ride" → ongoing → "Complete Ride" → completed.
//  The map + ETA update live as the driver's own location updates
//  (LocationManager) and as the ride document changes.
//

import SwiftUI

struct ActiveDriverRideView: View {

    @StateObject private var viewModel: ActiveDriverRideViewModel
    @StateObject private var locationManager = LocationManager.shared
    @EnvironmentObject private var router: Router

    init(rideId: String) {
        _viewModel = StateObject(wrappedValue: ActiveDriverRideViewModel(rideId: rideId))
    }

    var body: some View {
        Group {
            if viewModel.isCompleted {
                completedScreen
            } else if viewModel.isCancelled {
                statusScreen(
                    icon: "xmark.circle.fill",
                    tint: .red,
                    title: "Ride cancelled",
                    message: "The rider cancelled this ride."
                )
            } else {
                activeContent
            }
        }
        .navigationTitle("Active Ride")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(!viewModel.isCompleted && !viewModel.isCancelled)
        .onAppear {
            locationManager.requestPermissionIfNeeded()
            locationManager.startUpdating()
            viewModel.start()
        }
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

    private var activeContent: some View {
        VStack(spacing: 0) {
            LiveRideMapView(
                pickupCoordinate: viewModel.ride?.pickupLocation.geoPoint.clCoordinate,
                dropoffCoordinate: viewModel.ride?.dropoffLocation.geoPoint.clCoordinate,
                driverCoordinate: locationManager.currentLocation
            )
            .frame(maxHeight: .infinity)

            bottomCard
        }
    }

    private var bottomCard: some View {
        VStack(spacing: 14) {
            riderCard

            HStack {
                Text(viewModel.isOngoing ? "Heading to drop-off" : "Heading to pickup")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let eta = viewModel.etaMinutes {
                    Text("ETA \(Int(eta.rounded())) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    if viewModel.isEnRouteToPickup {
                        await viewModel.startRide()
                    } else if viewModel.isOngoing {
                        await viewModel.completeRide()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isUpdatingStatus {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isEnRouteToPickup ? "Start Ride" : "Complete Ride")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isUpdatingStatus)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var riderCard: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: viewModel.rider?.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.rider?.name ?? "Rider")
                    .font(.body.weight(.semibold))
                if let fare = viewModel.ride?.estimatedFare {
                    Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", fare)) estimated")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Terminal states

    // Phase 10 — shows the final fare/payment method from the receipt
    // RideService.completeRide wrote, instead of a plain "nice work" message.
    private var completedScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Ride completed")
                .font(.title2.bold())

            if let fare = viewModel.ride?.fare {
                VStack(spacing: 4) {
                    Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", fare.total))")
                        .font(.title.bold())
                    Text("Paid with \(PaymentMethod(rawValue: fare.paymentMethod)?.displayName ?? fare.paymentMethod.capitalized)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }

            Text("Nice work — you're free to go online for the next request.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Back to Driver Home") {
                router.pop()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }

    private func statusScreen(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(tint)
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Back to Driver Home") {
                router.pop() // pop this screen only — DriverHomeView stays on the stack
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        ActiveDriverRideView(rideId: "preview-ride-id")
            .environmentObject(Router())
    }
}
