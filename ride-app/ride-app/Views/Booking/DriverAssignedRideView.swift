//
//  DriverAssignedRideView.swift
//  RideBookingApp
//
//  Phase 7 — Ride Booking Flow (Rider Side)
//
//  Shown once ride.status is "accepted" or "ongoing" — displays the
//  assigned driver's name/photo/car/plate/rating pulled from Firestore
//  by BookRideViewModel. Live driver-location-on-map arrives in Phase 9;
//  for now this is a status card, not the live map.
//

import SwiftUI

struct DriverAssignedRideView: View {

    @ObservedObject var viewModel: BookRideViewModel

    private var statusText: String {
        viewModel.phase == .ongoing ? "On the way to your destination" : "Your driver is on the way"
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(statusText)
                .font(.title3.weight(.semibold))
                .padding(.top, 24)

            driverCard

            tripSummaryCard

            Spacer()

            Button(role: .destructive) {
                viewModel.showCancelConfirmation = true
            } label: {
                Text("Cancel Ride")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .confirmationDialog(
            "Cancel this ride?",
            isPresented: $viewModel.showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Cancel Ride", role: .destructive) {
                Task { await viewModel.cancelRide() }
            }
            Button("Keep Ride", role: .cancel) {}
        }
    }

    private var driverCard: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: viewModel.assignedDriver?.photoURL ?? "")) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.assignedDriver?.name ?? "Driver")
                    .font(.body.weight(.semibold))

                if let rating = viewModel.assignedDriver?.rating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let vehicle = viewModel.assignedDriver?.vehicle {
                    Text("\(vehicle.color) \(vehicle.model) • \(vehicle.plateNumber)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private var tripSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(viewModel.pickupAddress, systemImage: "circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)
            Label(viewModel.dropoffAddress, systemImage: "mappin")
                .foregroundStyle(.red)
                .font(.subheadline)
            HStack {
                Text(viewModel.selectedVehicleType.displayName)
                Text("•")
                Text("\(Constants.Fare.currencySymbol)\(String(format: "%.2f", viewModel.fareEstimate.total)) estimated")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    DriverAssignedRideView(
        viewModel: BookRideViewModel(
            pickupAddress: "123 Main St",
            pickupCoordinate: nil,
            dropoffAddress: "456 Market St",
            dropoffCoordinate: nil,
            distanceKm: 5.2,
            durationMin: 14
        )
    )
}
